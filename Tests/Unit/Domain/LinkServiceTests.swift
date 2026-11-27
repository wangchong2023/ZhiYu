//
//  LinkServiceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 LinkService 开展自动化单元测试验证。
//
import XCTest
import UFPCore
@testable import ZhiYuUnitTestHost

@MainActor
final class LinkServiceTests: XCTestCase {
    var sut: LinkService!
    var mockPages: [KnowledgePage]!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        sut = LinkService()
        
        // 构造 Mock 数据
        let page1 = KnowledgePage(title: "Swift", content: "iOS Development language.")
        var page2 = KnowledgePage(title: "Architecture", content: "Clean Architecture in [[Swift]].")
        page2.aliases = ["Arch"]
        
        var page3 = KnowledgePage(title: "Design", content: "UI Design for [[Arch]].")
        page3.tags = ["UI", "UX"]
        
        mockPages = [page1, page2, page3]
    }
    
    @MainActor
    override func tearDown() async throws {
        sut = nil
        mockPages = nil
        try await super.tearDown()
    }
    
    // MARK: - Test pageByTitle
    func testPageByTitle_ExactMatch() async {
        let result = await sut.pageByTitle("Swift", in: mockPages)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Swift")
    }
    
    func testPageByTitle_CaseInsensitive() async {
        let result = await sut.pageByTitle("swift", in: mockPages)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Swift")
    }
    
    func testPageByTitle_AliasMatch() async {
        let result = await sut.pageByTitle("Arch", in: mockPages)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Architecture")
    }
    
    // MARK: - Test Backlinks
    func testBacklinks_DirectLink() async {
        guard let swiftPage = await sut.pageByTitle("Swift", in: mockPages) else {
            XCTFail("Swift page should exist")
            return
        }
        
        let results = await sut.backlinks(for: swiftPage.id, in: mockPages)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Architecture")
    }
    
    func testBacklinks_AliasLink() async {
        guard let archPage = await sut.pageByTitle("Architecture", in: mockPages) else {
            XCTFail("Architecture page should exist")
            return
        }
        
        let results = await sut.backlinks(for: archPage.id, in: mockPages)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Design")
    }
    
    // MARK: - Test Search
    func testSearch_ByTag() async {
        let results = await sut.search(query: "UI", in: mockPages)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Design")
    }
    
    func testSearch_ByContent() async {
        let results = await sut.search(query: "Development", in: mockPages)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Swift")
    }
    
    // MARK: - Test pageByID
    func testPageByID() async {
        let firstPage = mockPages[0]
        let result = await sut.pageByID(firstPage.id, in: mockPages)
        XCTAssertEqual(result?.title, "Swift")
        
        let nonexistent = await sut.pageByID(UUID(), in: mockPages)
        XCTAssertNil(nonexistent)
    }
    
    // MARK: - Test Search Relevance Sorting All Branches
    func testSearch_RelevanceSorting_AllBranches() async {
        let query = "ios"
        let p1 = KnowledgePage(title: "iOS Development", content: "contains nothing special")
        let p2 = KnowledgePage(title: "iOS", content: "exact match")
        let p3 = KnowledgePage(title: "Learning iOS", content: "contains match")
        let p4 = KnowledgePage(title: "Other", content: "content contains ios")
        
        let searchPages = [p1, p2, p3, p4]
        let results = await sut.search(query: query, in: searchPages)
        
        XCTAssertEqual(results.count, 4)
        // 1. 精确匹配最优先 (p2)
        XCTAssertEqual(results[0].title, "iOS")
        // 2. 前缀匹配次之 (p1)
        XCTAssertEqual(results[1].title, "iOS Development")
        // 3. 包含匹配再次之 (p3)
        XCTAssertEqual(results[2].title, "Learning iOS")
        
        // 验证空查询直接返回原集合
        let emptyResults = await sut.search(query: "", in: mockPages)
        XCTAssertEqual(emptyResults.count, 3)
    }
    
    // MARK: - Test Hybrid Search with Diagnostics and All Branches
    func testHybridSearch_AllDiagnosticBranches() async throws {
        setupFullMockEnvironment()
        let embeddingManager = ServiceContainer.shared.resolve(EmbeddingManager.self)
        
        // 构造测试页面
        let page1 = KnowledgePage(id: UUID(), title: "SwiftUI Basics", content: "Learn declarative UI with SwiftUI.")
        let page2 = KnowledgePage(id: UUID(), title: "3D Graphics", content: "Learn 3D rendering.")
        let searchPages = [page1, page2]
        
        // 同步嵌入向量以确保索引缓存包含它们
        await embeddingManager.syncEmbeddings(pages: searchPages)
        
        // 1. 测试短查询分支 (< 3 字符，例如 "3D")
        let resultShort = await sut.hybridSearchWithDiagnostics(query: "3D", in: searchPages, embeddingProvider: embeddingManager)
        XCTAssertNotNil(resultShort.diagnostic)
        XCTAssertEqual(resultShort.diagnostic.query, "3D")
        
        // 2. 测试长查询分支 (>= 3 字符，例如 "swift")
        let resultLong = await sut.hybridSearchWithDiagnostics(query: "swift", in: searchPages, embeddingProvider: embeddingManager)
        XCTAssertNotNil(resultLong.diagnostic)
        XCTAssertEqual(resultLong.diagnostic.query, "swift")
        
        // 3. 极速爆破：测试 compactMap nil 返回分支
        // 我们在 embeddingManager 里注册了 page1 和 page2，但是在搜索传入的候选页面中故意把 page2 刨除（仅传入 page1）
        // 这样当语义搜索召回 page2.id 时，在 candidate pages 里面找不到它，就会触发 compactMap nil 分支！
        let resultCompactMapNil = await sut.hybridSearchWithDiagnostics(query: "swift", in: [page1], embeddingProvider: embeddingManager)
        XCTAssertEqual(resultCompactMapNil.results.count, 1)
        XCTAssertEqual(resultCompactMapNil.results.first?.id, page1.id)
    }
    
    // MARK: - Test RRF Algorithm
    func testRRFAlgorithm() async {
        let page1 = mockPages[0]
        let page2 = mockPages[1]
        let page3 = mockPages[2]
        
        let results = await sut.rrf(
            keywordResults: [page1, page2],
            semanticResults: [page2, page3],
            k: 60
        )
        
        XCTAssertEqual(results.count, 3)
        // page2 在两路中都存在，融合打分应当排在第一名
        XCTAssertEqual(results[0].id, page2.id)
    }
    
    // MARK: - Test All Tags Aggregation
    func testAllTagsAggregation() async {
        var page1 = KnowledgePage(title: "Page 1")
        page1.tags = ["#Swift", "#iOS"]
        
        var page2 = KnowledgePage(title: "Page 2")
        page2.tags = ["#Swift", "#Combine"]
        
        let tags = await sut.allTags(in: [page1, page2])
        XCTAssertEqual(tags.count, 3)
        XCTAssertEqual(tags[0].tag, "Swift")
        XCTAssertEqual(tags[0].count, 2)
    }
    
    // MARK: - Test Prepare Rename and Backlink Replacement
    func testPrepareRename_BacklinkReplacement() async {
        let mainPage = KnowledgePage(title: "Old Title", content: "Main content")
        let referencingPage = KnowledgePage(title: "Ref Page", content: "This is a reference to [[Old Title]].")
        let nonReferencingPage = KnowledgePage(title: "Other Page", content: "No reference here.")
        
        let allPages = [mainPage, referencingPage, nonReferencingPage]
        let updatedPages = await sut.prepareRename(page: mainPage, to: "New Title", in: allPages)
        
        XCTAssertEqual(updatedPages.count, 2)
        XCTAssertEqual(updatedPages[0].title, "New Title")
        XCTAssertEqual(updatedPages[1].title, "Ref Page")
        XCTAssertTrue(updatedPages[1].content.contains("[[New Title]]"))
        XCTAssertFalse(updatedPages[1].content.contains("[[Old Title]]"))
    }

    // MARK: - 缺陷 #239 回归：重命名保留别名/锚点、空白搜索与标签清洗

    func testPrepareRename_preservesAliasAndAnchorAndAvoidsPrefixCollision() async {
        let mainPage = KnowledgePage(title: "Old Title", content: "Self ref [[Old Title#Intro]]")
        let refPage = KnowledgePage(
            title: "Ref Page",
            content: "Link [[Old Title|显示名]], anchor [[Old Title#Sec1]], both [[old title#Sec2|别名]], unrelated [[Old Title 2]]."
        )

        let updated = await sut.prepareRename(page: mainPage, to: "New Title", in: [mainPage, refPage])
        XCTAssertEqual(updated.count, 2)
        XCTAssertEqual(updated[0].title, "New Title")
        XCTAssertEqual(updated[0].content, "Self ref [[New Title#Intro]]")
        XCTAssertEqual(
            updated[1].content,
            "Link [[New Title|显示名]], anchor [[New Title#Sec1]], both [[New Title#Sec2|别名]], unrelated [[Old Title 2]]."
        )
    }

    func testPrepareRename_blankOrUnchangedTitle_returnsEmpty() async {
        let mainPage = KnowledgePage(title: "Old Title", content: "Content")
        let refPage = KnowledgePage(title: "Ref", content: "[[Old Title]]")

        let blankResult = await sut.prepareRename(page: mainPage, to: "   \n ", in: [mainPage, refPage])
        XCTAssertTrue(blankResult.isEmpty, "空白新标题应直接拦截并返回空数组")

        let unchangedResult = await sut.prepareRename(page: mainPage, to: "Old Title", in: [mainPage, refPage])
        XCTAssertTrue(unchangedResult.isEmpty, "未变更的标题无需触发全库重写")
    }

    func testSearch_trimsWhitespaceAndTreatsBlankAsAllPages() async {
        let blankResults = await sut.search(query: "   \t  ", in: mockPages)
        XCTAssertEqual(blankResults.count, mockPages.count, "纯空白查询应返回全集")

        let trimmedResults = await sut.search(query: "  Swift  ", in: mockPages)
        XCTAssertEqual(trimmedResults.first?.title, "Swift", "带首尾空格的查询应精确命中目标标题")
    }

    func testAllTags_filtersBlankTagsAndDeduplicatesWithinSinglePage() async {
        var page1 = KnowledgePage(title: "Page 1")
        page1.tags = ["#Swift", "Swift", "  ", "#", "# iOS "]

        let tags = await sut.allTags(in: [page1])
        XCTAssertEqual(tags.count, 2)
        XCTAssertEqual(tags.first(where: { $0.tag == "Swift" })?.count, 1, "单页内重复标签不应重复计数")
        XCTAssertEqual(tags.first(where: { $0.tag == "iOS" })?.count, 1)
    }
}

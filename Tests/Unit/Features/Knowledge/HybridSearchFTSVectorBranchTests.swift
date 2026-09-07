//
//  HybridSearchFTSVectorBranchTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 LinkService 与 SearchStore 的混合检索（FTS5+向量）RRF 倒数排名融合算法、短查询权重动态调整与防抖搜索状态机分支。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

private final class LocalMockEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    var forcedResults: [(id: UUID, score: Float)] = []
    
    func getAllEmbeddings() async -> [UUID: [Float]] { [:] }
    func syncEmbeddings(pages: [KnowledgePage]) async {}
    func updateEmbedding(for page: KnowledgePage) async {}
    func indexChunks(pageID: UUID, chunks: [PageChunk]) async {}
    func vectorizeChunks(chunks: [String]) async -> [[Float]] { [] }
    func search(query: String, topK: Int) async -> [(id: UUID, score: Float)] { forcedResults }
    func multiQuerySearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func hydeSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func selfReflectionSearch(query: String, candidates: [(chunk: PageChunk, score: Float)]) async -> [(chunk: PageChunk, score: Float)] { [] }
    func advancedSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func loadInitialCache() async {}
    func clearCacheAndReload() async {}
}

@MainActor
final class HybridSearchFTSVectorBranchTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 四级相关性排序：精确标题 > 前缀标题 > 包含标题 > 正文关键词

    func testSearch_RelevanceTierSorting() async {
        let linkService = LinkService()
        let page1 = KnowledgePage(title: "Raft 分布式共识详细解析", content: "其他正文")
        let page2 = KnowledgePage(title: "Raft", content: "完全一致标题")
        let page3 = KnowledgePage(title: "分布式系统导论", content: "正文包含 raft 算法讨论")
        let page4 = KnowledgePage(title: "深入理解 Raft 核心机制", content: "标题包含")

        let results = await linkService.search(query: "Raft", in: [page1, page2, page3, page4])

        XCTAssertEqual(results.first?.title, "Raft", "完全一致的标题应排在第一位")
        XCTAssertEqual(results[1].title, "Raft 分布式共识详细解析", "前缀匹配的标题应排在第二位")
        XCTAssertEqual(results[2].title, "深入理解 Raft 核心机制", "标题包含应排在第三位")
        XCTAssertEqual(results.last?.title, "分布式系统导论", "仅正文包含的应排在最后")
    }

    // MARK: - 2. 短查询（如 "AI" / "3D"）动态加权分支

    func testHybridSearch_WithShortQuery_BoostsKeywordWeight() async {
        let linkService = LinkService()
        let pageA = KnowledgePage(title: "AI 智能体研发指南", content: "智能代理与 LLM")
        let pageB = KnowledgePage(title: "机器学习导论", content: "基础算法讨论")

        let mockEmbedding = LocalMockEmbeddingProvider()
        let result = await linkService.hybridSearchWithDiagnostics(
            query: "AI",
            in: [pageA, pageB],
            embeddingProvider: mockEmbedding
        )

        XCTAssertFalse(result.results.isEmpty, "混合检索应当返回结果")
        XCTAssertEqual(result.results.first?.id, pageA.id, "短查询加权后精准标题关键词应排名第一")
        XCTAssertNotNil(result.diagnostic, "应当生成诊断指标")
    }

    // MARK: - 3. 语义向量结果为空时全退至全文关键词检索分支

    func testHybridSearch_WhenVectorEmpty_FallsBackToKeyword() async {
        let linkService = LinkService()
        let page = KnowledgePage(title: "Karpathy LLM Wiki 架构", content: "本地知识库深度合成")

        let emptyEmbedding = LocalMockEmbeddingProvider()
        emptyEmbedding.forcedResults = []

        let result = await linkService.hybridSearchWithDiagnostics(
            query: "Karpathy",
            in: [page],
            embeddingProvider: emptyEmbedding
        )

        XCTAssertEqual(result.results.count, 1, "向量结果为空时应自动兜底返回关键词搜索结果")
        XCTAssertEqual(result.results.first?.id, page.id)
    }

    // MARK: - 4. SearchStore 防抖、高级搜索防御与清除状态机分支

    func testSearchStore_PerformAdvancedSearch_WhenEmptyQuery_ReturnsEmptyDirectly() async {
        let searchStore = SearchStore()
        let results = await searchStore.performAdvancedSearch(query: "   \n\t  ")

        XCTAssertTrue(results.isEmpty, "空查询不应触发混合检索")
        XCTAssertNil(searchStore.lastSearchDiagnostic)
        XCTAssertFalse(searchStore.isSearching)
    }

    func testSearchStore_ClearAll_ResetsAllState() {
        let searchStore = SearchStore()
        searchStore.searchText = "Swift 严格并发"
        searchStore.isSearching = true
        searchStore.searchResults = [KnowledgePage(title: "测试", content: "内容")]
        searchStore.isAdvancedSearching = true

        searchStore.clearAll()

        XCTAssertTrue(searchStore.searchText.isEmpty)
        XCTAssertTrue(searchStore.searchResults.isEmpty)
        XCTAssertFalse(searchStore.isSearching)
        XCTAssertFalse(searchStore.isAdvancedSearching)
        XCTAssertNil(searchStore.lastSearchDiagnostic)
    }
}

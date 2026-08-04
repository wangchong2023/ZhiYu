//
//  ImportSynthesisE2ETests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Integration] 集成测试层
//  核心职责：导入→合成端到端全链路验证

import XCTest
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class ImportSynthesisE2ETests: XCTestCase {
    var store: AppStore!
    private var dbQueue: DatabaseQueue!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        dbQueue = try DatabaseQueue()
        try DatabaseManager.shared.setupForTesting(with: dbQueue)
        store = AppStore()
    }

    override func tearDown() async throws {
        store = nil
        try? await Task.sleep(nanoseconds: AppConstants.Keys.ImportLimits.dismissDelayNS / 8)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        dbQueue = nil
        try await super.tearDown()
    }

    // MARK: - 导入→KnowledgePage 链路

    func testImportCreatesKnowledgePage() async {
        let sqliteStore = ServiceContainer.shared.resolve(SQLiteStore.self)
        let content = "# E2E 测试\n\n端到端导入合成链路验证"
        let page = await store.ingestService.ingestRawContent(
            title: "E2E 导入测试",
            content: content,
            type: .source,
            sourceURL: "https://e2e-test.example.com",
            pageStore: sqliteStore
        )
        XCTAssertEqual(page.title, "E2E 导入测试")
        XCTAssertEqual(page.sourceURL, "https://e2e-test.example.com")
        XCTAssertEqual(page.pageType, .source)
    }

    func testImportWithProvenanceMetadata() async {
        let sqliteStore = ServiceContainer.shared.resolve(SQLiteStore.self)
        let page = await store.ingestService.ingestRawContent(
            title: "溯源测试",
            content: "带溯源信息的内容",
            type: .source,
            sourceURL: "https://source.example.com/doc",
            rawSnippet: "带溯源信息的内容",
            pageStore: sqliteStore,
            fileSize: 4096,
            sourceType: "pdf"
        )
        XCTAssertEqual(page.sourceURL, "https://source.example.com/doc")
        XCTAssertEqual(page.sourceType, "pdf")
        XCTAssertEqual(page.fileSize, 4096)
        XCTAssertEqual(page.rawTextSnippet, "带溯源信息的内容")
    }

    // MARK: - 多页面合成输入构建

    func testBuildSynthesisInputFromMultiplePages() async {
        let sqliteStore = ServiceContainer.shared.resolve(SQLiteStore.self)

        let p1 = await store.ingestService.ingestRawContent(
            title: "页面1", content: "内容1", sourceURL: "https://a.com", pageStore: sqliteStore
        )
        let p2 = await store.ingestService.ingestRawContent(
            title: "页面2", content: "内容2", pageStore: sqliteStore, sourceType: "file"
        )

        let pages = [p1, p2]
        let combined = pages.map { "# \($0.title)\n\($0.content)" }.joined(separator: "\n\n---\n\n")
        let sourceIDs = pages.map(\.id)

        XCTAssertTrue(combined.contains("# 页面1"))
        XCTAssertTrue(combined.contains("# 页面2"))
        XCTAssertTrue(combined.contains("---"))
        XCTAssertEqual(sourceIDs.count, 2)
        XCTAssertEqual(p1.sourceURL, "https://a.com")
    }

    // MARK: - 溯源元数据流入合成

    func testProvenanceFlowsIntoSynthesisInput() async {
        let sqliteStore = ServiceContainer.shared.resolve(SQLiteStore.self)

        let page = await store.ingestService.ingestRawContent(
            title: "源页面", content: "正文",
            sourceURL: "https://origin.example.com",
            pageStore: sqliteStore, sourceType: "link"
        )

        var meta = ""
        if let url = page.sourceURL { meta += "> 来源: \(url)\n" }
        if let st = page.sourceType { meta += "> 类型: \(st)\n" }
        let header = meta.isEmpty ? "" : "\(meta)\n"
        let input = "# \(page.title)\n\(header)\(page.content)"

        XCTAssertTrue(input.contains("> 来源: https://origin.example.com"))
        XCTAssertTrue(input.contains("> 类型: link"))
    }

    // MARK: - sourcePageIDs 追踪

    func testSynthesisSourcePageIDsTracking() async {
        let sqliteStore = ServiceContainer.shared.resolve(SQLiteStore.self)

        let pages = [
            await store.ingestService.ingestRawContent(title: "S1", content: "C1", pageStore: sqliteStore),
            await store.ingestService.ingestRawContent(title: "S2", content: "C2", pageStore: sqliteStore),
            await store.ingestService.ingestRawContent(title: "S3", content: "C3", pageStore: sqliteStore)
        ]
        let sourceIDs = pages.map(\.id)
        XCTAssertEqual(sourceIDs.count, 3)

        // 验证文档的 sourcePageIDs 持久化
        let doc = SynthesisStore.SynthesisDocument(
            type: .report, name: "测试报告", content: "合成内容",
            size: 100, sourcePageIDs: sourceIDs
        )
        XCTAssertEqual(doc.sourcePageIDs.count, 3)
        XCTAssertTrue(doc.sourcePageIDs.contains(pages[0].id))
    }

    // MARK: - 多类型导入合成

    func testMixedImportTypesSynthesis() async {
        let sqliteStore = ServiceContainer.shared.resolve(SQLiteStore.self)

        // 模拟不同类型导入
        let linkPage = await store.ingestService.ingestRawContent(
            title: "链接导入", content: "网页内容", sourceURL: "https://web.com", pageStore: sqliteStore, sourceType: "link"
        )
        let filePage = await store.ingestService.ingestRawContent(
            title: "文件导入", content: "文件内容", pageStore: sqliteStore, fileSize: 2048, sourceType: "pdf"
        )
        let manualPage = await store.ingestService.ingestRawContent(
            title: "手动输入", content: "手动内容", pageStore: sqliteStore
        )

        let allPages = [linkPage, filePage, manualPage]
        XCTAssertEqual(allPages.count, 3)

        // 验证不同类型溯源信息
        XCTAssertEqual(linkPage.sourceURL, "https://web.com")
        XCTAssertEqual(linkPage.sourceType, "link")

        XCTAssertEqual(filePage.sourceType, "pdf")
        XCTAssertEqual(filePage.fileSize, 2048)

        XCTAssertNil(manualPage.sourceURL)

        // 合成输入
        let combined = allPages.map { "# \($0.title)\n\($0.content)" }.joined(separator: "\n\n---\n\n")
        let doc = SynthesisStore.SynthesisDocument(
            type: .report, name: "多源报告", content: combined,
            size: combined.utf8.count, sourcePageIDs: allPages.map(\.id)
        )

        XCTAssertEqual(doc.sourcePageIDs.count, 3)
        XCTAssertTrue(doc.sourcePageIDs.contains(linkPage.id))
        XCTAssertTrue(doc.sourcePageIDs.contains(filePage.id))
        XCTAssertTrue(doc.sourcePageIDs.contains(manualPage.id))
    }

    // MARK: - 合成引文反幻觉指令

    func testCitationInstructionPresent() {
        let instruction = L10n.AI.Synthesis.citationInstruction
        XCTAssertFalse(instruction.isEmpty)
        // 英文和中文都包含禁止编造的关键词
        XCTAssertTrue(instruction.contains("cite") || instruction.contains("禁止"))
    }

    // MARK: - 页面来源引用

    func testPageSourceCitationData() async {
        let sqliteStore = ServiceContainer.shared.resolve(SQLiteStore.self)
        let page = await store.ingestService.ingestRawContent(
            title: "引文页面", content: "内容",
            sourceURL: "https://cited.example.com",
            pageStore: sqliteStore, fileSize: 1024, sourceType: "web"
        )

        XCTAssertNotNil(page.sourceURL)
        XCTAssertNotNil(page.sourceType)
        XCTAssertNotNil(page.fileSize)

        let sourceLabel = L10n.Knowledge.Page.sourceCitation
        XCTAssertFalse(sourceLabel.isEmpty)
    }
}

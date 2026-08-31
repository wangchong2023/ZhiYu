//
//  IngestStoreErrorStateTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 测试层
//  核心职责：测试 IngestStore 在智能摄入、标签与图标装配、PDF 元数据生命周期及异常任务流转下的状态行为。
//

import XCTest
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class IngestStoreErrorStateTests: XCTestCase {

    private var store: IngestStore!
    private var pageStore: (any AnyPageStoreCapabilities)!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        pageStore = ServiceContainer.shared.resolve((any AnyPageStoreCapabilities).self)
        store = IngestStore()
    }

    override func tearDown() async throws {
        store = nil
        pageStore = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 常规摄入流程与标签及自定义图标

    func testPerformStandardIngestSuccess() async throws {
        let title = "标准测试文档"
        let content = "# 标题\n\n这是一段用于测试摄入管道的标准正文。"
        let tags = ["架构", "Swift"]
        let icon = "book.closed"

        let page = try await store.performIngest(
            title: title,
            content: content,
            type: .concept,
            tags: tags,
            customIcon: icon,
            useSmart: false,
            useDeepScan: false
        )

        XCTAssertEqual(page.title, title)
        XCTAssertEqual(page.tags, tags)
        XCTAssertEqual(page.customIcon, icon)
    }

    // MARK: - 2. 智能摄入完成与已有页面关联

    func testFinalizeSmartIngestLinkResolution() async throws {
        // 先在仓库中建立一个已存在的关联页面
        _ = try await pageStore.createPage(
            title: "关联已有页面",
            pageType: .concept,
            customIcon: nil,
            content: "前置知识点",
            tags: [],
            sourceURL: nil,
            rawSnippet: nil,
            fileSize: nil,
            sourceType: nil
        )

        let smartResult = SmartIngestResult(
            title: "新智能页面",
            compiledContent: "# 智能编译内容\n\n这是智能摄入解析后的内容。",
            suggestedTags: ["AI", "RAG"],
            suggestedType: "concept",
            relatedTitles: ["关联已有页面", "未命中页面"],
            summary: "这是摘要"
        )

        let page = await store.finalizeSmartIngest(
            title: "新智能页面",
            result: smartResult,
            customIcon: "sparkles"
        )

        XCTAssertEqual(page.title, "新智能页面")
        XCTAssertEqual(page.tags, ["AI", "RAG"])
        XCTAssertEqual(page.customIcon, "sparkles")
        XCTAssertFalse(page.relatedPageIDs.isEmpty, "命中已有页面时应建立关联 ID")
    }

    // MARK: - 3. PDF 元数据管理生命周期

    func testPDFMetadataCRUD() async {
        let docInfo = PDFDocumentInfo(
            title: "用户手册",
            fileName: "test_manual.pdf",
            pageCount: 12
        )

        // 保存元数据
        await store.savePDFDocument(docInfo)

        // 读取单个
        let loaded = await store.loadPDFDocument(id: docInfo.id)
        XCTAssertEqual(loaded?.title, "用户手册")
        XCTAssertEqual(loaded?.pageCount, 12)

        // 加载全量
        let allDocs = await store.loadPDFDocuments()
        XCTAssertTrue(allDocs.contains { $0.id == docInfo.id })

        // 删除元数据
        await store.deletePDFDocument(docInfo)
        let afterDelete = await store.loadPDFDocument(id: docInfo.id)
        XCTAssertNil(afterDelete)
    }
}

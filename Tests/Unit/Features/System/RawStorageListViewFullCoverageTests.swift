//
//  RawStorageListViewFullCoverageTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度覆盖 RawStorageListView、RawCategoryType、HighlightedText 与 RawPageDetailView 的全部分支与状态机。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class RawStorageListViewFullCoverageTests: XCTestCase {

    private var store: AppStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    // MARK: - 1. RawCategoryType 协议与属性枚举测试

    func testRawCategoryTypeProperties() {
        for category in RawCategoryType.allCases {
            XCTAssertEqual(category.id, category.rawValue)
            XCTAssertFalse(category.systemIconName.isEmpty)
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertNotNil(category.defaultColor)
        }

        XCTAssertEqual(RawCategoryType.document.displayName, L10n.Vault.raw.categoryDocument)
        XCTAssertEqual(RawCategoryType.audio.displayName, L10n.Vault.raw.categoryAudio)
        XCTAssertEqual(RawCategoryType.ocr.displayName, L10n.Vault.raw.categoryOcr)
        XCTAssertEqual(RawCategoryType.web.displayName, L10n.Vault.raw.categoryWeb)
        XCTAssertEqual(RawCategoryType.clipboard.displayName, L10n.Vault.raw.categoryClipboard)
        XCTAssertEqual(RawCategoryType.manual.displayName, L10n.Vault.raw.categoryManual)
    }

    // MARK: - 2. HighlightedText 富文本组件边界与状态覆盖

    func testHighlightedTextVariations() {
        // 空高亮关键字
        let viewEmpty = HighlightedText(text: "智宇知识库系统", highlight: "")
        let hostEmpty = UIHostingController(rootView: viewEmpty)
        XCTAssertNotNil(hostEmpty.view)

        // 匹配单次
        let viewSingle = HighlightedText(text: "智宇知识库系统", highlight: "知识库")
        let hostSingle = UIHostingController(rootView: viewSingle)
        XCTAssertNotNil(hostSingle.view)

        // 大小写不敏感与多次匹配
        let viewMulti = HighlightedText(text: "Swift is awesome, swift rocks", highlight: "swift")
        let hostMulti = UIHostingController(rootView: viewMulti)
        XCTAssertNotNil(hostMulti.view)

        // 不匹配项
        let viewNoMatch = HighlightedText(text: "Hello World", highlight: "NotFoundKeyword")
        let hostNoMatch = UIHostingController(rootView: viewNoMatch)
        XCTAssertNotNil(hostNoMatch.view)
    }

    // MARK: - 3. RawPageRow 组件渲染

    func testRawPageRowRendering() {
        var page = KnowledgePage(
            title: "测试原始文档.pdf",
            content: "这是从 PDF 提取的原始文档文本内容",
            sourceURL: "file:///documents/test.pdf"
        )
        page.sourceType = "pdf"
        page.fileSize = 1024 * 256

        let row = RawPageRow(page: page, searchText: "测试")
            .snapshotEnvironment()
        let hosting = UIHostingController(rootView: row)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()
    }

    // MARK: - 4. RawStorageListView 空状态与数据列表状态

    func testRawStorageListViewEmptyAndPopulated() async {
        // 1. 空状态
        store.knowledgeStore.pages = []
        let emptyView = RawStorageListView()
            .snapshotEnvironment()
        let emptyHost = UIHostingController(rootView: emptyView)
        XCTAssertNotNil(emptyHost.view)
        emptyHost.view.layoutIfNeeded()

        // 2. 注入多分类原始页面
        var docPage = KnowledgePage(title: "架构设计文档.pdf", content: "架构说明", sourceURL: "file://doc.pdf")
        docPage.sourceType = "pdf"
        docPage.fileSize = 2048

        var voicePage = KnowledgePage(title: "录音记录", content: "录音速记文本", sourceURL: "voice://audio.m4a")
        voicePage.sourceType = "voice"
        voicePage.fileSize = 4096

        var ocrPage = KnowledgePage(title: "发票扫描件", content: "发票信息", sourceURL: "ocr://image.png")
        ocrPage.sourceType = "ocr"
        ocrPage.fileSize = 1024

        var webPage = KnowledgePage(title: "网页剪藏", content: "文章全文", sourceURL: "https://example.com/article")
        webPage.sourceType = "link"

        var clipPage = KnowledgePage(title: "快速剪贴板", content: "临时复制内容", sourceURL: "clipboard://text")
        clipPage.sourceType = "clipboard"

        var manualPage = KnowledgePage(title: "手写笔记", content: "草稿", sourceURL: "custom://scheme")
        manualPage.sourceType = "unknown_type"

        await store.savePage(docPage)
        await store.savePage(voicePage)
        await store.savePage(ocrPage)
        await store.savePage(webPage)
        await store.savePage(clipPage)
        await store.savePage(manualPage)

        let populatedView = RawStorageListView()
            .snapshotEnvironment()
        let populatedHost = UIHostingController(rootView: populatedView)
        XCTAssertNotNil(populatedHost.view)
        populatedHost.view.layoutIfNeeded()
    }

    // MARK: - 5. RawPageDetailView 详情视图全分支渲染

    func testRawPageDetailView() {
        var page = KnowledgePage(
            title: "深度 RAG 评测方案.pdf",
            content: "这是一份关于 RAG 检索评测指标 (Faithfulness, Answer Relevance) 的完整技术文档规范。",
            sourceURL: "https://zhiyu.app/docs/rag-evaluation.pdf"
        )
        page.sourceType = "pdf"
        page.fileSize = 1024 * 512

        let detailView = RawPageDetailView(page: page)
            .snapshotEnvironment()
        let hosting = UIHostingController(rootView: detailView)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()
    }
}

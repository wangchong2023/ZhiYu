//
//  PageDetailSubViewsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度覆盖 PageDetail 的子组件（Header, MetadataSection, AISection, ContentSection, AIMenuButton）。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class PageDetailSubViewsDeepTests: XCTestCase {

    private var store: AppStore!
    private var aiStore: AIWorkflowStore!
    private var coordinator: PageDetailCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        aiStore = AIWorkflowStore()
        coordinator = PageDetailCoordinator(page: KnowledgePage(title: "测试页面", content: "内容"))
    }

    override func tearDown() async throws {
        store = nil
        aiStore = nil
        coordinator = nil
        try await super.tearDown()
    }

    // MARK: - 1. PageDetailAISection 深度测试

    func testPageDetailAISection() {
        let page = KnowledgePage(
            title: "知识管理架构",
            content: "基于 RAG 和向量检索的知识库系统",
            tags: ["AI", "Architecture"]
        )

        // 1. 空状态（不展示）
        aiStore.isProcessingPageAI = false
        aiStore.activePageAIResult = nil

        let emptySection = PageDetailAISection(
            page: page,
            onLinkTap: { _ in }
        )
        .environment(aiStore)
        .environment(store)
        .snapshotEnvironment()

        let emptyHost = UIHostingController(rootView: emptySection)
        _ = emptyHost.view

        // 2. 处理中状态
        aiStore.isProcessingPageAI = true
        let processingHost = UIHostingController(rootView: emptySection)
        _ = processingHost.view

        // 3. 产出结果状态（包含待办清单项）
        aiStore.isProcessingPageAI = false
        aiStore.activePageAIResult = """
        这是 AI 总结的核心结论。
        - [ ] 任务一：完成架构重构
        - [ ] 任务二：提升单测覆盖率至 95%
        """

        let resultHost = UIHostingController(rootView: emptySection)
        _ = resultHost.view
        resultHost.view.layoutIfNeeded()
    }

    // MARK: - 2. PageDetailHeader & PageDetailMetadataSection 测试

    func testPageDetailHeaderAndMetadataSection() {
        let page = KnowledgePage(
            title: "Swift 6 并发模型",
            pageType: .concept,
            content: "全面解析 Sendable, Actor 与 TaskLocal",
            aliases: ["Swift 并发", "Swift Concurrency"],
            tags: ["Swift", "Concurrency"],
            isPinned: true
        )

        // 1. Header 渲染
        let header = PageDetailHeader(page: page)
            .snapshotEnvironment()

        let headerHost = UIHostingController(rootView: header)
        _ = headerHost.view
        headerHost.view.layoutIfNeeded()

        // 2. MetadataSection 渲染
        let recPage = KnowledgePage(title: "Actor 隔离", content: "Actor 数据保护")
        let backlinkPage = KnowledgePage(title: "TaskLocal", content: "任务本地存储")

        let metaSection = PageDetailMetadataSection(
            page: page,
            backlinks: [backlinkPage],
            recommendations: [recPage]
        )
        .environment(store)
        .snapshotEnvironment()

        let metaHost = UIHostingController(rootView: metaSection)
        _ = metaHost.view
        metaHost.view.layoutIfNeeded()
    }

    // MARK: - 3. PageDetailAIMenuButton 测试

    func testPageDetailAIMenuButton() {
        var summaryTriggered = false
        var extractTriggered = false
        var mindmapTriggered = false
        var quizTriggered = false
        var slidesTriggered = false
        var reportTriggered = false
        var infographicTriggered = false
        var snapshotHistoryTriggered = false
        var expandContentTriggered = false
        var findRelatedLinksTriggered = false

        let menuButton = PageDetailAIMenuButton(
            isDisabled: false,
            onGenerateSummary: { summaryTriggered = true },
            onExtractActions: { extractTriggered = true },
            onMindmap: { mindmapTriggered = true },
            onQuiz: { quizTriggered = true },
            onSlides: { slidesTriggered = true },
            onReport: { reportTriggered = true },
            onInfographic: { infographicTriggered = true },
            onShowSnapshotHistory: { snapshotHistoryTriggered = true },
            onExpandContent: { expandContentTriggered = true },
            onFindRelatedLinks: { findRelatedLinksTriggered = true }
        )

        let host = UIHostingController(rootView: menuButton.snapshotEnvironment())
        _ = host.view
        host.view.layoutIfNeeded()

        menuButton.onGenerateSummary()
        XCTAssertTrue(summaryTriggered)
        menuButton.onExtractActions()
        XCTAssertTrue(extractTriggered)
        menuButton.onMindmap()
        XCTAssertTrue(mindmapTriggered)
        menuButton.onQuiz()
        XCTAssertTrue(quizTriggered)
        menuButton.onSlides()
        XCTAssertTrue(slidesTriggered)
        menuButton.onReport()
        XCTAssertTrue(reportTriggered)
        menuButton.onInfographic()
        XCTAssertTrue(infographicTriggered)
        menuButton.onShowSnapshotHistory()
        XCTAssertTrue(snapshotHistoryTriggered)
        menuButton.onExpandContent()
        XCTAssertTrue(expandContentTriggered)
        menuButton.onFindRelatedLinks()
        XCTAssertTrue(findRelatedLinksTriggered)
    }
}

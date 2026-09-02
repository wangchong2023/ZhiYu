//
//  PageDetailViewFullCoverageTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度覆盖 PageDetailView 的全部渲染分支、AI 任务抽屉、面包屑导航、本地与远程来源引用卡片。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class PageDetailViewFullCoverageTests: XCTestCase {

    private var store: AppStore!
    private var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        router = ServiceContainer.shared.resolveOptional(Router.self) ?? Router.shared
    }

    override func tearDown() async throws {
        store = nil
        router = nil
        try await super.tearDown()
    }

    // MARK: - 1. 基础页面详情视图渲染与多类型测试

    func testPageDetailViewBasicRendering() async {
        var page = KnowledgePage(
            title: "核心概念页",
            content: "# 概念定义\n这是一个 [[关联页]] 的内容，包含 **重点** 与代码：\n```swift\nlet x = 1\n```",
            sourceURL: "https://zhiyu.app/docs"
        )
        page.pageType = .concept
        page.tags = ["Swift", "Architecture"]
        page.aliases = ["别名A", "别名B"]
        page.isPinned = true
        await store.savePage(page)

        let view = PageDetailView(page: page)
            .snapshotEnvironment()
        let hosting = UIHostingController(rootView: view)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()
    }

    // MARK: - 2. 本地文件来源与远程 URL 引用栏分支测试

    func testSourceCitationBars() async {
        // 本地文件来源
        var localPage = KnowledgePage(
            title: "本地文档",
            content: "从本地 PDF 提取",
            sourceURL: "file:///Users/constantine/Documents/report.pdf"
        )
        localPage.sourceType = "pdf"
        localPage.fileSize = 1024 * 1024 * 5
        await store.savePage(localPage)

        let localView = PageDetailView(page: localPage)
            .snapshotEnvironment()
        let localHost = UIHostingController(rootView: localView)
        XCTAssertNotNil(localHost.view)
        localHost.view.layoutIfNeeded()

        // 远程 Web 来源
        var webPage = KnowledgePage(
            title: "在线文章",
            content: "从网页剪藏",
            sourceURL: "https://example.com/posts/ai-wiki"
        )
        webPage.sourceType = "web"
        await store.savePage(webPage)

        let webView = PageDetailView(page: webPage)
            .snapshotEnvironment()
        let webHost = UIHostingController(rootView: webView)
        XCTAssertNotNil(webHost.view)
        webHost.view.layoutIfNeeded()
    }

    // MARK: - 3. 欢迎 Aha 卡片渲染

    func testWelcomeAhaPromptCardRendering() async {
        let welcomePage = KnowledgePage(
            title: L10n.Common.Demo.Welcome.title,
            content: "欢迎使用智宇知识库系统"
        )
        await store.savePage(welcomePage)

        let view = PageDetailView(page: welcomePage)
            .snapshotEnvironment()
        let hosting = UIHostingController(rootView: view)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()
    }

    // MARK: - 4. 面包屑历史与深层导航视图

    func testBreadcrumbsWithHistory() async {
        let rootPage = KnowledgePage(title: "首页", content: "根内容")
        let middlePage = KnowledgePage(title: "中级页", content: "中间内容")
        let currentPage = KnowledgePage(title: "当前终端页", content: "终端内容")

        await store.savePage(rootPage)
        await store.savePage(middlePage)
        await store.savePage(currentPage)

        router.addToHistory(rootPage)
        router.addToHistory(middlePage)
        router.addToHistory(currentPage)

        let view = PageDetailView(page: currentPage)
            .snapshotEnvironment()
        let hosting = UIHostingController(rootView: view)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()

        router.clearHistory()
    }

    // MARK: - 5. 潜在 AI 关联发现状态分支

    func testPotentialLinksSections() async {
        let targetPage = KnowledgePage(title: "测试页", content: "内容")
        await store.savePage(targetPage)

        let aiStore = store.aiWorkflowStore

        // 1. 扫描中
        aiStore?.isScanningAI = true
        let scanningView = PageDetailView(page: targetPage)
            .snapshotEnvironment()
        let hostScanning = UIHostingController(rootView: scanningView)
        XCTAssertNotNil(hostScanning.view)
        hostScanning.view.layoutIfNeeded()

        // 2. 发现潜在链接
        aiStore?.isScanningAI = false
        aiStore?.potentialLinks = [
            PotentialLinkSuggestion(
                sourcePageID: targetPage.id,
                sourceTitle: targetPage.title,
                targetTitle: "关联目标页"
            )
        ]
        let linksView = PageDetailView(page: targetPage)
            .snapshotEnvironment()
        let hostLinks = UIHostingController(rootView: linksView)
        XCTAssertNotNil(hostLinks.view)
        hostLinks.view.layoutIfNeeded()

        aiStore?.potentialLinks = []
    }
}

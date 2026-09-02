//
//  PageDetailSheetModalsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class PageDetailSheetModalsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. PageDetailCoordinator Actions & States

    func testPageDetailCoordinatorStateAndMutations() async throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        let initialPage = KnowledgePage(
            title: "Karpathy RAG LLM Wiki",
            pageType: .concept,
            content: "Detailed markdown content with [[SubPage]] link.",
            tags: ["AI", "LLM", "Wiki"],
            isPinned: false,
            sourceURL: "file:///notes/karpathy.md",
            fileSize: 4096,
            sourceType: "md"
        )
        store.pages = [initialPage]

        let coordinator = PageDetailCoordinator(page: initialPage)

        // 1. 切换置顶
        await coordinator.togglePin()
        XCTAssertTrue(coordinator.page.isPinned)
        await coordinator.togglePin()
        XCTAssertFalse(coordinator.page.isPinned)

        // 2. 切换编辑态与弹窗状态
        coordinator.isEditing = true
        XCTAssertTrue(coordinator.isEditing)
        coordinator.isEditing = false

        coordinator.showBacklinks = true
        XCTAssertTrue(coordinator.showBacklinks)

        coordinator.showIconPicker = true
        XCTAssertTrue(coordinator.showIconPicker)

        coordinator.showSnapshotHistory = true
        XCTAssertTrue(coordinator.showSnapshotHistory)

        coordinator.showDeleteConfirmation = true
        XCTAssertTrue(coordinator.showDeleteConfirmation)

        // 3. AI 交互触发
        coordinator.generateSummary()
        coordinator.extractActions()
        coordinator.expandContent()
        coordinator.performSynthesis(type: .mindmap)
        coordinator.performSynthesis(type: .quiz)
        coordinator.performSynthesis(type: .report)
    }

    // MARK: - 2. PageDetailView Full Mounting with Welcome & Source Citation

    func testPageDetailViewMountingAndWelcomeCard() throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        
        // 1. 挂载欢迎 Aha 提示卡片页面
        let welcomePage = KnowledgePage(
            title: L10n.Common.Demo.Welcome.title,
            pageType: .concept,
            content: "Welcome to ZhiYu knowledge system."
        )
        store.pages = [welcomePage]

        let welcomeDetailView = PageDetailView(page: welcomePage)
            .snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let hostWelcome = UIHostingController(rootView: welcomeDetailView)
        window.rootViewController = hostWelcome
        window.makeKeyAndVisible()
        hostWelcome.view.layoutIfNeeded()
        XCTAssertNotNil(hostWelcome.view)

        // 2. 挂载带外部链接和文件引用的页面
        let sourcePage = KnowledgePage(
            title: "Research Paper",
            pageType: .source,
            content: "Extracted abstract and citations",
            sourceURL: "https://arxiv.org/abs/2301.00000",
            fileSize: 1024 * 500,
            sourceType: "pdf"
        )
        let sourceDetailView = PageDetailView(page: sourcePage)
            .snapshotEnvironment()
        let hostSource = UIHostingController(rootView: sourceDetailView)
        window.rootViewController = hostSource
        hostSource.view.layoutIfNeeded()
        XCTAssertNotNil(hostSource.view)
    }
}

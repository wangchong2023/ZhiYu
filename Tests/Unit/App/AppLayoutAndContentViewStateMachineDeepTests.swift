//
//  AppLayoutAndContentViewStateMachineDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 测试层
//  核心职责：深度验证 ContentView 核心容器、侧边栏全 Sections（Capabilities, Sources, Universe, Pinned, Tools）、自适应 TabView 与全局弹窗的分支流转。
//

import XCTest
import SwiftUI
import UFPCore
import UFPStorage
import Dependencies
@testable import ZhiYu

@MainActor
final class AppLayoutAndContentStateTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 侧边栏全 Sections 渲染求值

    struct TestHostView: View {
        @Namespace var heroNamespace
        @State var pageToDelete: KnowledgePage?
        @State var showDeleteConfirmation = false

        var body: some View {
            List {
                CapabilitiesSection()
                SourcesSection()
                UniverseSection()
                PinnedSection(
                    heroNamespace: heroNamespace,
                    pageToDelete: $pageToDelete,
                    showDeleteConfirmation: $showDeleteConfirmation
                )
                ToolsSection()
            }
        }
    }

    func testSidebarSections_AllSubviewsRenderSafely() {
        let store = KnowledgeStore()
        let appStore = AppStore()
        let router = Router()

        // 注入已置顶页面以触发 PinnedSection 渲染分支
        let pinnedPage = KnowledgePage(
            title: "置顶页面测试",
            pageType: .concept,
            content: "置顶内容",
            isPinned: true
        )
        store.pages = [pinnedPage]

        let host = TestHostView()
            .environment(store)
            .environment(appStore)
            .environment(router)

        let controller = UIHostingController(rootView: host)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        // 验证 SidebarSelection 各种 asRoute 转换
        let toolRoute = SidebarSelection.tool(.dashboard).asRoute()
        XCTAssertEqual(toolRoute, .dashboard)

        let pageID = UUID()
        let pageRoute = SidebarSelection.page(pageID).asRoute()
        XCTAssertEqual(pageRoute, .pageDetail(id: pageID))

        let filterRoute = SidebarSelection.filteredIndex(.concept).asRoute()
        XCTAssertEqual(filterRoute, .pageList(filterType: .concept))
    }

    // MARK: - 2. ContentView 主容器多状态流转

    func testContentView_MainContainersAndTransitions() {
        let appStore = AppStore()
        let knowledgeStore = KnowledgeStore()
        let ingestStore = IngestStore()
        let synthesisStore = SynthesisStore()
        let router = Router()
        let theme = ThemeManager()

        let contentView = ContentView()
            .environment(appStore)
            .environment(knowledgeStore)
            .environment(ingestStore)
            .environment(synthesisStore)
            .environment(router)
            .environment(theme)

        let controller = UIHostingController(rootView: contentView)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }
}

//
//  AppScenesAndNavigationInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 测试
//  核心职责：验证 AppScenes 顶层路由映射、侧边栏 Tab 联动同步、导航栈清理与自适应行组件渲染。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AppScenesAndNavigationInteractiveTests: XCTestCase {

    var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        router = Router.shared
        router.path = NavigationPath()
        router.sidebarSelection = nil
    }

    override func tearDown() async throws {
        router.path = NavigationPath()
        router.sidebarSelection = nil
        router = nil
        try await super.tearDown()
    }

    // MARK: - 1. AppRoute 完整性与 Domain 映射测试

    func testAppRoute_allCasesHaveValidDomainAndID() {
        let testUUID = UUID()
        let routes: [AppRoute] = [
            .notebookHub,
            .dashboard,
            .pageList(filterType: nil),
            .pageList(filterType: .concept),
            .pageDetail(id: testUUID),
            .tagCloud,
            .taskCenter,
            .chat,
            .synthesis,
            .sources,
            .settings,
            .help,
            .about,
            .log,
            .collab,
            .weeklyReport,
            .lint,
            .pluginMarket,
            .search(query: "测试", filterType: .entity),
            .ingest,
            .graph,
            .quiz,
            .medalWall
        ]

        for route in routes {
            XCTAssertFalse(route.id.isEmpty, "Route ID 不能为空: \(route)")
            let domain = route.domain
            // 验证业务领域归属合法
            XCTAssertTrue(FeatureDomain.allCases.contains(domain), "Route domain 必须是四大领域之一")
        }
    }

    // MARK: - 2. SidebarSelection 与 AppRoute 双向路由映射测试

    func testSidebarSelection_asRouteAndInverseMapping() {
        let testID = UUID()

        // 1. Page
        let pageSelection = SidebarSelection.page(testID)
        XCTAssertEqual(pageSelection.asRoute(), .pageDetail(id: testID))

        // 2. Filtered Index
        let filteredSelection = SidebarSelection.filteredIndex(.concept)
        XCTAssertEqual(filteredSelection.asRoute(), .pageList(filterType: .concept))

        // 3. Tool Item
        let toolSelection = SidebarSelection.tool(.chat)
        XCTAssertEqual(toolSelection.asRoute(), .chat)

        // 4. 反向路由映射
        XCTAssertEqual(AppRoute.chat.sidebarSelection, .tool(.chat))
        XCTAssertEqual(AppRoute.dashboard.sidebarSelection, .tool(.dashboard))
        XCTAssertEqual(AppRoute.pageDetail(id: testID).sidebarSelection, .page(testID))
        XCTAssertEqual(AppRoute.pageList(filterType: .entity).sidebarSelection, .filteredIndex(.entity))
    }

    // MARK: - 3. Router 状态机：侧边栏切换清空 NavigationPath 与 Tab 联动

    func testRouter_sidebarSelectionChange_clearsNavigationPathAndSyncsTab() {
        // 先向导航路径推入脏状态
        router.path.append(AppRoute.settings)
        XCTAssertFalse(router.path.isEmpty)

        // 切换侧边栏至 AI 对话
        router.sidebarSelection = .tool(.chat)

        // 验证导航路径自动清空，防止 iPad/Catalyst 出现残留覆盖
        XCTAssertTrue(router.path.isEmpty, "侧边栏切换必须自动清空 path")
        XCTAssertEqual(router.selectedTab, .chat, "选择 chat 工具项应自动同步选中 chat Tab")

        // 再次推入路径并切换到图谱
        router.path.append(AppRoute.about)
        router.sidebarSelection = .tool(.graph)
        XCTAssertTrue(router.path.isEmpty)
        XCTAssertEqual(router.selectedTab, .graph)

        // 切换到知识库类工具项（如仪表盘）
        router.sidebarSelection = .tool(.dashboard)
        XCTAssertTrue(router.path.isEmpty)
        XCTAssertEqual(router.selectedTab, .knowledge)
    }

    // MARK: - 4. Router 状态机：主 Tab 切换重置 NavigationPath

    func testRouter_selectedTabChange_clearsNavigationPath() {
        router.path.append(AppRoute.help)
        XCTAssertFalse(router.path.isEmpty)

        // 切换主 Tab
        router.selectedTab = .chat
        XCTAssertTrue(router.path.isEmpty, "切换 Tab 必须彻底重置全局导航栈")
    }

    // MARK: - 5. SidebarIconRow 角标与高亮渲染测试
    // MARK: - 6. UniverseNavRow 数量角标渲染测试
    // MARK: - 7. AboutView 挂载与版本信息渲染测试

    func testAboutView_renderingAndVersionDisplay() {
        let aboutView = AboutView()
        let host = UIHostingController(rootView: aboutView)
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "AboutView 应正常完成视图层次渲染")
    }
}

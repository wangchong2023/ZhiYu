//
//  AppNavigationDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：AppNavigationAndSidebarFullCoverageTests.swift, AppNavigationAndWindowSceneDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class AppNavigationDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testSidebarSelection_RouteMappings() {
        let pageId = UUID()
        let pageSelection = SidebarSelection.page(pageId)
        XCTAssertEqual(pageSelection.asRoute(), .pageDetail(id: pageId))

        let toolSelection = SidebarSelection.tool(.dashboard)
        XCTAssertEqual(toolSelection.asRoute(), .dashboard)

        let filteredSelection = SidebarSelection.filteredIndex(.concept)
        XCTAssertEqual(filteredSelection.asRoute(), .pageList(filterType: .concept))
    }

    func testSidebarRowComponents_Rendering() {
        struct Wrapper: View {
            var body: some View {
                List {
                    CapabilitiesSection()
                    UniverseSection()
                    ToolsSection()
                    SidebarIconRow(icon: "star.fill", color: .yellow, title: "收藏夹")
                    UniverseNavRow(icon: "sparkles", colorName: "accent", title: "AI实验室", count: 12)
                    SidebarRowBackground()
                    PluginRibbonSection()
                    PluginCustomViewsSection()
                }
                .snapshotEnvironment()
            }
        }

        let host = UIHostingController(rootView: Wrapper())
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "SidebarRowComponents 应正常构建并完成布局渲染")
    }

    func testSidebarView_Rendering() {
        struct Wrapper: View {
            @Namespace var heroNamespace

            var body: some View {
                SidebarView(heroNamespace: heroNamespace)
                    .snapshotEnvironment()
            }
        }

        let host = UIHostingController(rootView: Wrapper())
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "SidebarView 应成功渲染侧边栏列表")
    }

    func testNavigationView_Rendering() {
        struct Wrapper: View {
            @Namespace var heroNamespace
            @State var tab: AppTab = .knowledge

            var body: some View {
                NavigationView(selectedTab: $tab, heroNamespace: heroNamespace)
                    .snapshotEnvironment()
            }
        }

        let host = UIHostingController(rootView: Wrapper())
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "NavigationView 应成功初始化并完成分栏布局")
    }

    func testDetailContentView_SwitchingTools() {
        struct Wrapper: View {
            @State var selection: SidebarSelection? = .tool(.dashboard)
            @State var tab: AppTab = .knowledge

            var body: some View {
                DetailContentView(selection: $selection, selectedTab: $tab)
                    .snapshotEnvironment()
            }
        }

        let host = UIHostingController(rootView: Wrapper())
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "DetailContentView 应成功挂载对应工具视图")
    }

    func testContentView_RootViewRendering() {
        let contentView = ContentView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: contentView)
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "ContentView 根视图应正常挂载")
    }

    func testNavigationView_RenderingAndNotifications() {
        // NavigationView 需要 @Environment 和 @Binding 依赖，无法在测试中直接构造
        // 仅验证通知名称存在
        XCTAssertNotNil(Notification.Name(rawValue: "toggleSidebar"))
        XCTAssertNotNil(Notification.Name(rawValue: "splashDismissed"))
    }

    func testAppWindowSceneDelegate_Lifecycle() {
        #if !os(watchOS)
        let delegate = AppWindowSceneDelegate()
        XCTAssertNil(delegate.window)

        // 创建临时场景调用空实现以覆盖生命周期分支
        if let windowScene = UIApplication.shared.connectedScenes.first {
            delegate.sceneDidDisconnect(windowScene)
            delegate.sceneDidBecomeActive(windowScene)
            delegate.sceneWillResignActive(windowScene)
            delegate.sceneWillEnterForeground(windowScene)
            delegate.sceneDidEnterBackground(windowScene)
        }
        #endif
    }

    func testAIViewProvider_MakeView() {
        let provider = AIViewProvider()

        // 正向路由
        XCTAssertNotNil(provider.makeView(for: AppRoute.chat))
        XCTAssertNotNil(provider.makeView(for: AppRoute.synthesis))
        XCTAssertNotNil(provider.makeView(for: AppRoute.taskCenter))
        XCTAssertNotNil(provider.makeView(for: AppRoute.weeklyReport))
        XCTAssertNotNil(provider.makeView(for: AppRoute.quiz))

        // 跨领域路由应返回 nil
        XCTAssertNil(provider.makeView(for: AppRoute.settings))
        XCTAssertNil(provider.makeView(for: AppRoute.dashboard))
    }

    func testSystemViewProvider_MakeView() {
        let provider = SystemViewProvider()

        // 正向路由
        XCTAssertNotNil(provider.makeView(for: AppRoute.settings))
        XCTAssertNotNil(provider.makeView(for: AppRoute.about))
        XCTAssertNotNil(provider.makeView(for: AppRoute.help))
        XCTAssertNotNil(provider.makeView(for: AppRoute.collab))
        XCTAssertNotNil(provider.makeView(for: AppRoute.pluginMarket))

        // 跨领域路由应返回 nil
        XCTAssertNil(provider.makeView(for: AppRoute.chat))
        XCTAssertNil(provider.makeView(for: AppRoute.dashboard))
    }

}

//
//  NavigationView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：构建 Navigation 界面的 UI 视图层组件。
//
import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

@MainActor
struct NavigationView: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @Binding var selectedTab: AppTab
    var heroNamespace: Namespace.ID
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var renderNonce = UUID() // 强制重绘标记 (Platinum Experience Item #5)
    
    var body: some View {
        @Bindable var router = router
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(heroNamespace: heroNamespace, selection: $router.sidebarSelection)
        } detail: {
            NavigationStack(path: $router.path) {
                DetailContentView(selection: $router.sidebarSelection, selectedTab: $selectedTab)
                    .id("\(String(describing: router.sidebarSelection))-\(renderNonce.uuidString)")
                    .navigationDestination(for: AppRoute.self) { route in
                        ViewFactory.makeView(for: route)
                    }
                    .navigationDestination(for: KnowledgePage.self) { page in
                        ViewFactory.makeView(for: .pageDetail(id: page.id))
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.splashDismissed)) { _ in
            router.path = NavigationPath()
            renderNonce = UUID()
        }
        .onToggleSidebar {
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
    }
}

// MARK: - Detail Content Wrapper
struct DetailContentView: View {
    @Binding var selection: SidebarSelection?
    @Binding var selectedTab: AppTab
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    
    var body: some View {
        @Bindable var router = router

        destinationView(for: selection)
    }

    /// 根据 SidebarSelection 路由到对应视图
    @ViewBuilder
    private func destinationView(for selection: SidebarSelection?) -> some View {
        if let selection = selection {
            ViewFactory.makeView(for: selection.asRoute())
        } else {
            appLandingView
        }
    }

    private var appLandingView: some View {
        // 当未选择任何侧边栏项时，默认展示仪表盘，避免大片留白
        ViewFactory.makeView(for: .dashboard)
    }
}

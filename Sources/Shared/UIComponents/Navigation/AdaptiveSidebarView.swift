//
//  AdaptiveSidebarView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：构建 AdaptiveSidebar 界面的 UI 视图层组件。
//
import SwiftUI

/// 响应式侧边栏 (iPad/Mac 专属)
/// 将传统的底部 Tab 转换为更符合大屏习惯的垂直侧边栏。
/// 响应式侧边栏视图 (iPad/Mac 专属)
/// 负责将大屏环境下的导航从底部 Tab 切换为侧边栏 List 模式，优化空间利用率与交互路径
@MainActor
struct AdaptiveSidebarView: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @Binding var selectedTab: AppTab
    
    var body: some View {
        // 在 iOS/Mac Catalyst 平台上，SwiftUI List 的单选绑定（selection）仅支持可选值类型（Optional）。
        // 因此通过自定义 Binding 将 Binding<AppTab> 桥接转换为 Binding<AppTab?>，以通过编译并保持行为一致。
        List(selection: Binding<AppTab?>(
            get: { selectedTab },
            set: { if let val = $0 { selectedTab = val } }
        )) {
            Section(L10n.Common.Sidebar.knowledge) {
                sidebarRow(for: .knowledge)
            }
            
            Section(L10n.Common.Sidebar.tools) {
                sidebarRow(for: .chat)
                sidebarRow(for: .ingest)
                sidebarRow(for: .synthesis)
                sidebarRow(for: .graph)
                
                // 快捷跳转到任务中心 (作为 Knowledge 模块的子操作)
                // 挂载 "SidebarTab_taskCenter" 标识符供 UI 自动化测试精准定位
                Button(action: handleTaskCenterClick) {
                    Label(L10n.AI.Task.centerTitle, systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("SidebarTab_taskCenter")
            }
        }
        #if !os(watchOS)
        .listStyle(.sidebar)
        #endif
        .navigationTitle(L10n.Common.appName)
        .toolbar {
            #if os(watchOS)
            ToolbarItem(placement: .automatic) {
                VaultBadge()
            }
            #else
            ToolbarItem(placement: .navigation) {
                VaultBadge()
            }
            #endif
            ToolbarItem(placement: .automatic) {
                UserProfileMenu()
            }
        }
        .id(router.languageForceUpdate)
    }
    
    /// 触发任务中心跳转逻辑，提供单元测试直接调用的入口
    func handleTaskCenterClick() {
        selectedTab = .knowledge
        router.navigateToTool(.taskCenter)
    }

    /// 渲染侧边栏中的单个导航行
    /// - Parameter tab: 要渲染的 AppTab 类型项
    /// - Returns: 返回挂载了唯一定位测试标识符 "SidebarTab_\(tab.rawValue)" 的视图行
    private func sidebarRow(for tab: AppTab) -> some View {
        Label(tab.displayTitle, systemImage: tab.icon)
            .foregroundStyle(selectedTab == tab ? Color.appAccent : .primary)
            .contentShape(Rectangle())
            // 在 iOS (iPadOS) 下，List 中的非 NavigationLink 普通行在点击时
            // 不会自动触发 selection 绑定值修改。因此我们通过 onTapGesture
            // 手动执行选中切换，保证大分类 Tab 能够随之被完美切换刷新。
            .onTapGesture {
                selectedTab = tab
            }
            .accessibilityIdentifier("SidebarTab_\(tab.rawValue)")
            .tag(tab)
    }
}

/// 响应式主内容区域
/// 响应式主内容区域视图
/// 负责根据侧边栏选中项动态分发内容视图，支持跨平台的导航逻辑一致性
@MainActor
struct AdaptiveDetailView: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @Binding var selectedTab: AppTab
    @Binding var selection: SidebarSelection?
    // // @Binding var languageForceUpdate: Bool
    var heroNamespace: Namespace.ID

    init(selectedTab: Binding<AppTab>, selection: Binding<SidebarSelection?>, heroNamespace: Namespace.ID) {
        self._selectedTab = selectedTab
        self._selection = selection
        self.heroNamespace = heroNamespace
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            Group {
                switch selectedTab {
                case .knowledge:
                    DetailContentView(selection: $selection, selectedTab: $selectedTab)
                case .chat:
                    ChatView(selectedTab: $selectedTab)
                case .graph:
                    GraphContainerView(heroNamespace: heroNamespace, selectedTab: $selectedTab)
                case .synthesis:
                    SynthesisView(selection: $selection, selectedTab: $selectedTab)
                case .ingest:
                    IngestView(selectedTab: $selectedTab)
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                makeDestinationView(for: route)
            }
            .navigationDestination(for: KnowledgePage.self) { page in
                makePageDetailView(for: page)
            }
        }
    }

    /// 根据路由构建对应的内容视图，提供单元测试直接调用的入口
    /// - Parameter route: 路由目的地类型 AppRoute
    /// - Returns: 目标内容视图
    @ViewBuilder

    /// 创建DestinationView
    func makeDestinationView(for route: AppRoute) -> some View {
        ViewFactory.makeView(for: route)
    }

    /// 根据知识库页面构建对应的详情视图，提供单元测试直接调用的入口
    /// - Parameter page: 知识库页面数据模型
    /// - Returns: 页面详情视图
    @ViewBuilder

    /// 创建PageDetailView
    func makePageDetailView(for page: KnowledgePage) -> some View {
        ViewFactory.makeView(for: .pageDetail(id: page.id))
    }
}

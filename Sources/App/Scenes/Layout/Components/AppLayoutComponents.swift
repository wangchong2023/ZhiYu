//
//  AppLayoutComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：SwiftUI 视图组件，构建应用的导航、侧边栏、布局等 UI 结构。
//
import SwiftUI
import UFPCore

extension ContentView {
    
    // MARK: - Main Containers
    
    @ViewBuilder

    /// mainContainer
    /// - Parameter tintColor: 着色Color
    func mainContainer(tintColor: Color) -> some View {
        if authSession.isLoggedIn || authSession.isGuest {
            Group {
                if vaultService.selectedVaultID != nil {
                    mainContent(tintColor: tintColor)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
                    NavigationStack {
                        NotebookHubView()
                            .id(router.languageForceUpdate)
                    }
                    .id("NotebookHub")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        } else {
            AuthView()
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    @ViewBuilder

    /// mainContent
    /// - Parameter tintColor: 着色Color
    func mainContent(tintColor: Color) -> some View {
        ZStack {
            adaptiveTabView(tintColor: tintColor)
            
            globalOverlaySheets()
            
            // UI 测试专用退出按钮：toolbar 中的 VaultBadge 在 principal 位置，
            // XCUITest 点击不可靠。添加一个透明的退出区域，仅在 UI 测试模式下显示。
            if TestModeDetector.isUITesting {
                Button {
                    vaultService.exitVault()
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("UITest_ExitVaultButton")
                .frame(width: DesignSystem.Metrics.uiTestButtonSize, height: DesignSystem.Metrics.uiTestButtonSize)
                .position(x: DesignSystem.Metrics.uiTestButtonSize / 2, y: DesignSystem.Metrics.uiTestButtonSize / 2)
            }
        }
        .appToast()
    }

    /// 渲染适配当前硬件平台与测试模式下的核心 TabView/SplitView 容器
    /// - Parameter tintColor: 全局着色色彩
    /// - Returns: 返回经过平台决策后的主内容容器视图
    @ViewBuilder
    private func adaptiveTabView(tintColor: Color) -> some View {
        #if !os(macOS)
        // 1. 若处于 iOS/iPadOS UI 自动化测试模式下，一律强制回退至 legacyTabView 以保障 TabBar 元素定位在 iPhone/iPad 上绝对可靠
        if TestModeDetector.isUITesting {
            legacyTabView(tintColor: tintColor)
        } else if appEnv.screenClass != .compact {
            if #available(iOS 18.0, *) {
                modernTabView(tintColor: tintColor)
            } else {
                legacyTabView(tintColor: tintColor)
            }
        } else {
            if #available(iOS 18.0, *) {
                modernTabView(tintColor: tintColor)
            } else {
                legacyTabView(tintColor: tintColor)
            }
        }
        #else
        // 2. macOS 桌面端或 macCatalyst 物理运行环境
        if appEnv.screenClass != .compact {
            adaptiveSplitView(tintColor: tintColor)
        } else {
            if #available(macOS 15.0, macCatalyst 18.0, *) {
                modernTabView(tintColor: tintColor)
            } else {
                legacyTabView(tintColor: tintColor)
            }
        }
        #endif
    }

    /// 渲染全局弹出的各种 Sheet 及悬浮引导图层
    /// - Returns: 返回附加了各种 sheet 和浮层的 overlay 视图
    @ViewBuilder
    private func globalOverlaySheets() -> some View {
        @Bindable var store = store
        @Bindable var router = router
        
        Color.clear
            .sheet(isPresented: $store.showCreateSheet) {
                CreatePageView()
                    .applySettingsPresentationSizing(screenClass: appEnv.screenClass)
            }
            
            // 统一挂载性能监控 Sheet，避免分散在互斥视图分支导致状态丢失
            .sheet(isPresented: $store.showPerfDashboard) {
                PerformanceDashboardView(service: store.performanceService)
            }
            .background {
                ZStack {
                    // 全局奖章奖励弹窗
                    if let medal = medalService.newlyEarnedMedal {
                        MedalRewardPopup(medal: medal) {
                            withAnimation(.spring()) {
                                medalService.newlyEarnedMedal = nil
                            }
                        }
                        .zIndex(DesignSystem.ZIndex.medalPopup)
                        .transition(.asymmetric(insertion: .opacity, removal: .scale.combined(with: .opacity)))
                    }
                    
                    // 功能引导弹窗 (Coach Marks)
                    if let coachMark = store.pendingCoachMark {
                        CoachMarkOverlay(type: coachMark, selectedTab: $router.selectedTab) {
                            store.pendingCoachMark = nil
                        }
                        .zIndex(DesignSystem.ZIndex.coachMark)
                    }
                }
            }
    }
    
    // MARK: - iPad/Mac Adaptive SplitView
    
    @ViewBuilder

    /// adaptive拆分View
    /// - Parameter tintColor: 着色Color
    func adaptiveSplitView(tintColor: Color) -> some View {
        #if os(watchOS)
        Text("Not used on watchOS")
        #else
        @Bindable var store = store
        @Bindable var router = router
        Group {
            if router.selectedTab == .knowledge {
                NavigationSplitView {
                    AdaptiveSidebarView(selectedTab: $router.selectedTab)
                } content: {
                    SidebarView(heroNamespace: heroNamespace, selection: $router.sidebarSelection)
                } detail: {
                    AdaptiveDetailView(selectedTab: $router.selectedTab, selection: $router.sidebarSelection, heroNamespace: heroNamespace)
                }
            } else {
                NavigationSplitView {
                    AdaptiveSidebarView(selectedTab: $router.selectedTab)
                } detail: {
                    AdaptiveDetailView(selectedTab: $router.selectedTab, selection: $router.sidebarSelection, heroNamespace: heroNamespace)
                }
            }
        }
        .tint(tintColor)
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
                .presentationDetents([.height(DesignSystem.Metrics.commandPaletteHeight)])
                .presentationBackground(.clear)
        }
        .background {
            Button(L10n.Common.Tab.search) { showCommandPalette.toggle() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
        }
        #endif
    }
    
    // MARK: - TabViews
    
    @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, *)
    @ViewBuilder

    /// modernTabView
    /// - Parameter tintColor: 着色Color
    func modernTabView(tintColor: Color) -> some View {
        #if os(watchOS)
        Text("Not used on watchOS")
        #else
        @Bindable var store = store
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab(AppTab.knowledge.displayTitle, systemImage: AppTab.knowledge.icon, value: AppTab.knowledge) {
                knowledgeTabContent
            }
            .accessibilityIdentifier("Knowledge")

            Tab(AppTab.chat.displayTitle, systemImage: AppTab.chat.icon, value: AppTab.chat) {
                chatTabContent
            }
            .accessibilityIdentifier("Chat")

            Tab(AppTab.ingest.displayTitle, systemImage: AppTab.ingest.icon, value: AppTab.ingest) {
                ingestTabContent
            }
            .accessibilityIdentifier("Ingest")

            Tab(AppTab.synthesis.displayTitle, systemImage: AppTab.synthesis.icon, value: AppTab.synthesis) {
                synthesisTabContent
            }
            .accessibilityIdentifier("Synthesis")

            Tab(AppTab.graph.displayTitle, systemImage: AppTab.graph.icon, value: AppTab.graph) {
                graphTabContent
            }
            .accessibilityIdentifier("Graph")
        }
        .tint(tintColor)
        .onOpenURL { url in
            if deepLinkService.handleURL(url) {
                consumeDeepLink()
            }
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
                .presentationDetents([.height(DesignSystem.Metrics.commandPaletteHeight)])
                .presentationBackground(.clear)
        }
        .background {
            Button(L10n.Common.action) {
                showCommandPalette.toggle()
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
        }
        #endif
    }
    
    @ViewBuilder

    /// legacyTabView
    /// - Parameter tintColor: 着色Color
    func legacyTabView(tintColor: Color) -> some View {
        #if os(watchOS)
        Text("Not used on watchOS")
        #else
        @Bindable var store = store
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            knowledgeTabContent
                .tabItem {
                    Label(AppTab.knowledge.displayTitle, systemImage: AppTab.knowledge.icon)
                }
                .accessibilityIdentifier("Knowledge")
                .tag(AppTab.knowledge)

            chatTabContent
                .accessibilityIdentifier("Chat")
                .tabItem {
                    Label(AppTab.chat.displayTitle, systemImage: AppTab.chat.icon)
                }
                .tag(AppTab.chat)

            ingestTabContent
                .accessibilityIdentifier("Ingest")
                .tabItem {
                    Label(AppTab.ingest.displayTitle, systemImage: AppTab.ingest.icon)
                }
                .tag(AppTab.ingest)

            synthesisTabContent
                .accessibilityIdentifier("Synthesis")
                .tabItem {
                    Label(AppTab.synthesis.displayTitle, systemImage: AppTab.synthesis.icon)
                }
                .tag(AppTab.synthesis)

            graphTabContent
                .accessibilityIdentifier("Graph")
                .tabItem {
                    Label(AppTab.graph.displayTitle, systemImage: AppTab.graph.icon)
                }
                .tag(AppTab.graph)
        }
        .tint(tintColor)
        .onOpenURL { url in
            if deepLinkService.handleURL(url) {
                consumeDeepLink()
            }
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
                .presentationDetents([.height(DesignSystem.Metrics.commandPaletteHeight)])
                .presentationBackground(.clear)
        }
        .background {
            Button(L10n.Common.action) {
                showCommandPalette.toggle()
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
        }
        #endif
    }
    
    // MARK: - Tab Contents
    
    @ViewBuilder
    var knowledgeTabContent: some View {
        @Bindable var router = router
        if appEnv.screenClass == .compact {
            NavigationStack(path: $router.path) {
                SidebarView(heroNamespace: heroNamespace, selection: $router.sidebarSelection)
                    .id(router.languageForceUpdate)
                    .navigationDestination(for: AppRoute.self) { route in
                        ViewFactory.makeView(for: route)
                    }
                    .navigationDestination(for: SidebarSelection.self) { selection in
                        ViewFactory.makeView(for: selection.asRoute())
                    }
                    .navigationDestination(for: KnowledgePage.self) { page in
                        ViewFactory.makeView(for: .pageDetail(id: page.id))
                    }
            }
        } else {
            NavigationView(selectedTab: $router.selectedTab, heroNamespace: heroNamespace)
                .id(router.languageForceUpdate)
        }
    }
    
    @ViewBuilder
    var chatTabContent: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            ChatView(selectedTab: $router.selectedTab)
                .id(router.languageForceUpdate)
                .navigationDestination(for: AppRoute.self) { route in
                    ViewFactory.makeView(for: route)
                }
        }
    }
    
    @ViewBuilder
    var graphTabContent: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            GraphContainerView(heroNamespace: heroNamespace, selectedTab: $router.selectedTab)
                .id(router.languageForceUpdate)
                .navigationDestination(for: AppRoute.self) { route in
                    ViewFactory.makeView(for: route)
                }
        }
    }
    
    @ViewBuilder
    var synthesisTabContent: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            SynthesisView(selection: $router.sidebarSelection, selectedTab: $router.selectedTab)
                .id(router.languageForceUpdate)
                .navigationDestination(for: AppRoute.self) { route in
                    ViewFactory.makeView(for: route)
                }
        }
    }

    @ViewBuilder
    var ingestTabContent: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            IngestView(selectedTab: $router.selectedTab)
                .id(router.languageForceUpdate)
                .navigationDestination(for: AppRoute.self) { route in
                ViewFactory.makeView(for: route)
            }
        }
    }

    /// 消费当前挂起的深度路由链接，并触发全局 UI 的无转场或 Tab 页切换
    func consumeDeepLink() {
        // 关键过程：从服务容器提取未消费的挂起链接，并在取出时自动清空挂起状态
        guard let link = deepLinkService.consumeDeepLink() else { return }
        
        switch link {
        case .openPage(let id):
            // 直达特定笔记详情页
            router.navigateToPage(id: id)
            
        case .openPageByTitle(let t):
            // 根据标题异步查找对应笔记，成功后跳转
            Task {
                if let p = await store.pageByTitle(t) {
                    await MainActor.run { router.navigateToPage(id: p.id) }
                }
            }
            
        case .search(let query):
            // 🟢 切换至搜索 Tab，并注入待搜索关键词
            router.navigateToTool(.search)
            store.searchStore.searchText = query
            
        case .create:
            // 🟢 补全：拉起全局新建卡片 Sheet 弹窗，用户可随时输入
            store.showCreateSheet = true
            
        case .ingest:
            // 🟢 补全：快捷切换到“知识摄入中心” Tab
            router.navigateToTool(.ingest)
            
        case .graph:
            // 🟢 补全：快捷切换到“知识关系图谱” Tab
            router.navigateToTool(.graph)
            
        case .chat:
            // 🟢 补全：快捷切换到“AI 智能对话” Tab
            router.navigateToTool(.chat)
        }
    }
}

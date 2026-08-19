//
//  SidebarView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：构建 Sidebar 界面的 UI 视图层组件。
//
import SwiftUI
import UFPCore
import Dependencies

@MainActor
struct SidebarView: View {
    // MARK: - Environment & Store
    @Environment(AppStore.self) var appStore
    @Environment(KnowledgeStore.self) var store
    @Environment(VaultService.self) var vaultService
    @Environment(IngestStore.self) var ingestStore
    @Environment(Router.self) var router
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    /// 全局注入的平台设备环境
    @Dependency(\.appEnvironment) private var appEnv: any AppEnvironmentProtocol
    
    // MARK: - Properties
    var heroNamespace: Namespace.ID
    var selection: Binding<SidebarSelection?>?
    
    // MARK: - Local State
    @State private var showDeleteConfirmation = false
    @State private var pageToDelete: KnowledgePage?

    // MARK: - Body
    var body: some View {
        @Bindable var router = router
        
        Group {
            // 注意：iPadOS 的 SwiftUI 会将 NavigationSplitView 侧边栏内部子视图的 horizontalSizeClass
            // 强行覆写为 .compact，因此无法用系统的 sizeClass 区分设备屏幕。采用全局设备 screenClass 进行高信度分支判定。
            if appEnv.screenClass == .compact {
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
            } else {
                List(selection: $router.sidebarSelection) {
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
        .background(
            PageBackgroundView(accentColor: themeManager.accentColor)
                .ignoresSafeArea()
        )
        .scrollContentBackground(.hidden)
        .modifier(SidebarListStyleModifier(horizontalSizeClass: horizontalSizeClass))
        .confirmationDialog(
            pageToDelete.map { L10n.Vault.Page.deletePageTitle($0.title) } ?? L10n.Vault.Page.deletePage,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Vault.Page.deletePage, role: .destructive) {
                if let page = pageToDelete {
                    Task { await store.deletePage(page) }
                }
            }
            Button(L10n.Common.cancel, role: .cancel) {
                pageToDelete = nil
            }
        }
        .sidebarToolbar(title: L10n.Common.Sidebar.title, appEnv: appEnv)
        .id(router.languageForceUpdate)
    }
}

// MARK: - Sidebar Custom Adaptive Toolbar
extension View {
    /// 自适应侧边栏专用工具栏
    /// - Parameters:
    ///   - title: 工具栏标题
    ///   - appEnv: 平台设备环境
    @MainActor

    /// sidebarToolbar
    /// - Parameter title: title
    /// - Parameter appEnv: appEnv
    func sidebarToolbar(title: String, appEnv: any AppEnvironmentProtocol) -> some View {
        self.modifier(SidebarToolbarModifier(title: title, appEnv: appEnv))
    }
}

/// 侧边栏工具栏修饰符 (大屏和小屏专属自适应)
struct SidebarToolbarModifier: ViewModifier {
    let title: String
    let appEnv: any AppEnvironmentProtocol
    
    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        if appEnv.screenClass == .compact {
            // 在手机 (Compact) 下：作为主标签页根视图，采用带有右上角头像的标准 appTabToolbar
            content.appTabToolbar(title: title)
        } else {
            // 在 iPad/Mac (Regular/Expansive) 下：侧边栏只保留 VaultBadge
            // UserProfileMenu 已在内容区顶部工具栏（AppSubPageToolbarModifier）中自动追加，无需重复放置
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    #if os(watchOS)
                    ToolbarItem(placement: .automatic) {
                        VaultBadge()
                    }
                    #else
                    ToolbarItem(placement: .principal) {
                        VaultBadge()
                    }
                    #endif
                }
        }
    }
}

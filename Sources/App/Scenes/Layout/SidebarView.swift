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
        // swiftlint:disable:next redundant_discardable_let
        let _ = showDeleteConfirmation
        
        Group {
            // 注意：iPadOS 的 SwiftUI 会将 NavigationSplitView 侧边栏内部子视图的 horizontalSizeClass
            // 强行覆写为 .compact，因此无法用系统的 sizeClass 区分设备屏幕。采用全局设备 screenClass 进行高信度分支判定。
            if appEnv.screenClass == .compact {
                List {
                    sidebarListContent
                }
            } else {
                List(selection: $router.sidebarSelection) {
                    sidebarListContent
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

    // MARK: - 侧边栏列表内容

    /// 侧边栏 List 的统一内容构建器
    /// 抽取 compact 与 regular 两种布局下完全相同的 Section 组合，避免重复书写。
    @ViewBuilder
    private var sidebarListContent: some View {
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
    @Environment(\.interfaceIdiom) private var idiom
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
            // macOS 三栏工具栏会合并各列标题，第二列不设 navigationTitle 以免与子页面标题重复显示。
            content
                .navigationTitle(idiom == .mac ? "" : title)
                .appNavigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // macOS 三栏工具栏会合并各列内容：第一列已提供 VaultBadge，
                    // 此处只保留导航标题，避免窗口顶部出现两个「项目调研」选择器。
                    if idiom != .mac {
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
}

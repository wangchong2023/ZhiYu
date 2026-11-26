//
//  AppToolbarModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI
import UFPDesignSystem

// MARK: - 跨平台工具栏位置适配 (收敛至文件作用域单点抽象)
#if os(macOS)
@MainActor
private extension ToolbarItemPlacement {
    static let platformTopBarTrailing: ToolbarItemPlacement = .primaryAction
    static let platformTopBarLeading: ToolbarItemPlacement = .navigation
}
#else
@MainActor
private extension ToolbarItemPlacement {
    static let platformTopBarTrailing: ToolbarItemPlacement = .topBarTrailing
    static let platformTopBarLeading: ToolbarItemPlacement = .topBarLeading
}
#endif

// MARK: - Root Tab Toolbar
/// 主标签页工具栏修饰符 (用于根页面)
struct AppTabToolbarModifier<Trailing: View>: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom
    let title: String
    let trailingItems: Trailing
    let showVaultBadge: Bool
    
    init(title: String, showVaultBadge: Bool = true, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.showVaultBadge = showVaultBadge
        self.trailingItems = trailing()
    }
    
    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .appNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                if idiom == .watch {
                    if showVaultBadge {
                        ToolbarItem(placement: .platformTopBarTrailing) {
                            VaultBadge()
                        }
                    }
                } else if showVaultBadge && idiom != .mac {
                    // macOS 的 NavigationSplitView 会把第一列 AdaptiveSidebarView 的 VaultBadge
                    // 合并进窗口工具栏，内容区不再重复渲染，避免出现两个知识库选择器。
                    ToolbarItem(placement: .principal) {
                        VaultBadge()
                    }
                }
                
                if idiom == .mac {
                    if Trailing.self != EmptyView.self {
                        ToolbarItem(placement: .primaryAction) {
                            trailingItems
                        }
                        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, *) {
                            ToolbarSpacer(.fixed)
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        UserProfileMenu()
                    }
                } else {
                    ToolbarItem(placement: .platformTopBarTrailing) {
                        trailingToolbarContent(trailingItems)
                    }
                }
            }
            .appToolbarBackgroundHidden()
    }
}

// MARK: - Sub Page Toolbar
/// 子页面工具栏修饰符 (解决返回按钮重叠)
struct AppSubPageToolbarModifier<Trailing: View>: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom
    let title: String
    let trailingItems: Trailing
    let showVaultBadge: Bool
    
    init(title: String, showVaultBadge: Bool = false, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.showVaultBadge = showVaultBadge
        self.trailingItems = trailing()
    }
    
    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        content
            .navigationTitle(idiom == .mac ? title : "")
            .appNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                if idiom == .watch {
                    ToolbarItem(placement: .platformTopBarLeading) {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.appText)
                    }
                } else if idiom != .mac {
                    // macOS 原生工具栏将 .principal 包裹成玻璃胶囊，直接使用 .navigationTitle(title) 呈现标准窗口标题；
                    // iOS/iPadOS 保留 .principal 居中标题与可选 VaultBadge。
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            Text(title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.appText)
                            
                            if showVaultBadge {
                                VaultBadge()
                                    .scaleEffect(0.85)
                                    .padding(.top, -4)
                            }
                        }
                    }
                }
                
                if idiom == .mac {
                    if Trailing.self != EmptyView.self {
                        ToolbarItem(placement: .primaryAction) {
                            trailingItems
                        }
                        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, *) {
                            ToolbarSpacer(.fixed)
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        UserProfileMenu()
                    }
                } else {
                    ToolbarItem(placement: .platformTopBarTrailing) {
                        trailingToolbarContent(trailingItems)
                    }
                }
            }
    }
}

// MARK: - 共享 trailing toolbar 内容
/// 构建 trailing 区域：非空时显示 trailingItems + UserProfileMenu，消除两处重复的 HStack + EmptyView 判断。
@ViewBuilder
@MainActor
private func trailingToolbarContent<Trailing: View>(_ trailingItems: Trailing) -> some View {
    HStack(spacing: DesignTokens.Spacing.atomic) {
        if Trailing.self != EmptyView.self {
            trailingItems
        }
        UserProfileMenu()
    }
}

extension View {
    /// 应用主标签页统一工具栏 (根页面使用)
    func appTabToolbar<Trailing: View>(title: String, showVaultBadge: Bool = true, @ViewBuilder trailing: @escaping () -> Trailing) -> some View {
        self.modifier(AppTabToolbarModifier(title: title, showVaultBadge: showVaultBadge, trailing: trailing))
    }
    
    /// appTabToolbar
    /// - Parameter title: title
    /// - Parameter showVaultBadge: 展示 VaultBadge
    func appTabToolbar(title: String, showVaultBadge: Bool = true) -> some View {
        self.modifier(AppTabToolbarModifier(title: title, showVaultBadge: showVaultBadge, trailing: { EmptyView() }))
    }
    
    /// 应用子页面统一工具栏 (解决重叠，保留返回路径)
    func appSubPageToolbar<Trailing: View>(title: String, showVaultBadge: Bool = false, @ViewBuilder trailing: @escaping () -> Trailing) -> some View {
        self.modifier(AppSubPageToolbarModifier(title: title, showVaultBadge: showVaultBadge, trailing: trailing))
    }
    
    /// appSubPageToolbar
    /// - Parameter title: title
    /// - Parameter showVaultBadge: 展示VaultBadge
    func appSubPageToolbar(title: String, showVaultBadge: Bool = false) -> some View {
        self.modifier(AppSubPageToolbarModifier(title: title, showVaultBadge: showVaultBadge, trailing: { EmptyView() }))
    }
}

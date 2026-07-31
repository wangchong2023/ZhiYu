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

// MARK: - Root Tab Toolbar
/// 主标签页工具栏修饰符 (用于根页面)
struct AppTabToolbarModifier<Trailing: View>: ViewModifier {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                #if os(watchOS)
                if showVaultBadge {
                    ToolbarItem(placement: .topBarTrailing) {
                        VaultBadge()
                    }
                }
                #else
                if showVaultBadge {
                    ToolbarItem(placement: .principal) {
                        VaultBadge()
                    }
                }
                #endif
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Spacing.atomic) {
                        if Trailing.self != EmptyView.self {
                            trailingItems
                        }
                        UserProfileMenu()
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - Sub Page Toolbar
/// 子页面工具栏修饰符 (解决返回按钮重叠)
struct AppSubPageToolbarModifier<Trailing: View>: ViewModifier {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                #if os(watchOS)
                ToolbarItem(placement: .topBarLeading) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.appText)
                }
                #else
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
                #endif
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Spacing.atomic) {
                        if Trailing.self != EmptyView.self {
                            trailingItems
                        }
                        UserProfileMenu()
                    }
                }
            }
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

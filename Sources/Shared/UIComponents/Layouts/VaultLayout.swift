//
//  VaultLayout.swift
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

/// 笔记本网格容器布局
public struct VaultGridLayout<Content: View>: View {
    let content: () -> Content
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: DesignSystem.Vault.gridCardMin, maximum: DesignSystem.Vault.gridCardMax), spacing: DesignSystem.Vault.gridSpacing)
    ]
    
    public var body: some View {
        LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.giant) {
            content()
        }
        .padding(.horizontal, DesignSystem.Vault.homePadding)
    }
}

/// 笔记本列表容器布局
public struct VaultListLayout<Content: View>: View {
    let content: () -> Content
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    public var body: some View {
        LazyVStack(spacing: DesignSystem.Vault.listSpacing) {
            content()
        }
        .padding(.horizontal, DesignSystem.Vault.homePadding)
    }
}

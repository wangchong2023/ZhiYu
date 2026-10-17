//
//  ViewModifiers.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] SPM Package — 物理归位
//  核心职责：通用基础 ViewModifier 集 —— 原子内边距/圆角裁切、卡片背景+圆角裁切。
//           沉淀自 ZhiYu App 层 Shared/UIComponents，供包内组件与上层共享。
//

import SwiftUI

// MARK: - 原子内边距 & 圆角裁切

public extension View {
    /// 注入基于设计系统的原子内边距修饰器
    /// - Parameters:
    ///   - edges: 内边距作用方向，默认全部边缘
    ///   - token: 强类型间距令牌
    func appPadding(_ edges: Edge.Set = .all, _ token: DesignTokens.SpacingToken) -> some View {
        self.padding(edges, token.value)
    }

    /// 注入基于设计系统的原子圆角裁切修饰器
    /// - Parameter token: 强类型圆角令牌
    func appCornerRadius(_ token: DesignTokens.RadiusToken) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: token.value))
    }
}

// MARK: - 卡片背景 + 圆角裁切

/// 卡片背景 + 圆角裁切修饰符
/// 消除重复的 `.background(Color.appCard).clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius))` 链
private struct AppCardClipModifier: ViewModifier {
    let cornerRadius: CGFloat
    let backgroundOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(Color.appCard.opacity(backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

public extension View {
    /// 应用卡片背景 + 圆角裁切（默认 cardRadius，不透明背景）
    func appCardClip(cornerRadius: CGFloat = DesignTokens.Spacing.cardRadius) -> some View {
        modifier(AppCardClipModifier(cornerRadius: cornerRadius, backgroundOpacity: DesignTokens.Colors.Opacity.fullOpacity))
    }

    /// 应用卡片背景 + 圆角裁切（自定义背景透明度）
    func appCardClip(cornerRadius: CGFloat, backgroundOpacity: Double) -> some View {
        modifier(AppCardClipModifier(cornerRadius: cornerRadius, backgroundOpacity: backgroundOpacity))
    }
}
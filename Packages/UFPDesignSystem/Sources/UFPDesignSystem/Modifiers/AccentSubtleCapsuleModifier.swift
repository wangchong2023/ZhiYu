//
//  AccentSubtleCapsuleModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 共享层
//  核心职责：Accent 透明背景胶囊 ViewModifier，消除 Features 中重复的 foregroundStyle(.appAccent) + padding + background(Color.appAccent.opacity(subtle)) + clipShape(Capsule) 链。
//

import SwiftUI

/// Accent 透明背景胶囊修饰符
///
/// 消除 `SourceRow`、`PageDetailHeader`、`UserProfileView`、`OnDeviceComponents` 中重复的
/// `padding(.horizontal:).padding(.vertical:).background(Color.appAccent.opacity(DesignTokens.Opacity.subtle)).clipShape(Capsule())` 模式。
/// 注意：不强制 foregroundStyle，由调用方自行设置字色。
public struct AccentSubtleCapsuleModifier: ViewModifier {
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat
    public var backgroundOpacity: Double

    public init(
        horizontalPadding: CGFloat = DesignTokens.Spacing.tightPadding,
        verticalPadding: CGFloat = DesignTokens.Spacing.atomic,
        backgroundOpacity: Double = DesignTokens.Opacity.subtle
    ) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.backgroundOpacity = backgroundOpacity
    }

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Color.appAccent.opacity(backgroundOpacity))
            .clipShape(Capsule())
    }
}

public extension View {
    /// Accent 透明背景胶囊样式：padding + background(appAccent.opacity) + clipShape(Capsule)
    /// 不强制 foregroundStyle，由调用方自行设置字色。
    func accentSubtleCapsule(
        horizontalPadding: CGFloat = DesignTokens.Spacing.tightPadding,
        verticalPadding: CGFloat = DesignTokens.Spacing.atomic,
        backgroundOpacity: Double = DesignTokens.Opacity.subtle
    ) -> some View {
        modifier(AccentSubtleCapsuleModifier(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            backgroundOpacity: backgroundOpacity
        ))
    }
}

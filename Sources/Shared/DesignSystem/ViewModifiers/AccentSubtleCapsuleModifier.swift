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
/// `padding(.horizontal:).padding(.vertical:).background(Color.appAccent.opacity(DesignSystem.Opacity.subtle)).clipShape(Capsule())` 模式。
/// 注意：不强制 foregroundStyle，由调用方自行设置字色。
struct AccentSubtleCapsuleModifier: ViewModifier {
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    var backgroundOpacity: Double

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Color.appAccent.opacity(backgroundOpacity))
            .clipShape(Capsule())
    }
}

extension View {
    /// Accent 透明背景胶囊样式：padding + background(appAccent.opacity) + clipShape(Capsule)
    /// 不强制 foregroundStyle，由调用方自行设置字色。
    func accentSubtleCapsule(
        horizontalPadding: CGFloat = DesignSystem.tightPadding,
        verticalPadding: CGFloat = DesignSystem.atomic,
        backgroundOpacity: Double = DesignSystem.Opacity.subtle
    ) -> some View {
        modifier(AccentSubtleCapsuleModifier(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            backgroundOpacity: backgroundOpacity
        ))
    }
}

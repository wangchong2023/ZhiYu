//
//  AccentCapsuleModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 共享层
//  核心职责：Accent 渐变胶囊 ViewModifier，消除 Features 中重复的 padding+background(LinearGradient)+clipShape(Capsule) 链。
//

import SwiftUI

/// Accent 渐变胶囊修饰符，消除重复的 padding+background(LinearGradient)+clipShape(Capsule) 链
struct AccentCapsuleModifier: ViewModifier {
    var horizontalPadding: CGFloat = DesignSystem.medium
    var verticalPadding: CGFloat = DesignSystem.small
    var gradientEndOpacity: Double = DesignSystem.Opacity.prominent

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                LinearGradient(
                    colors: [.appAccent, .appAccent.opacity(gradientEndOpacity)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
    }
}

extension View {
    /// Accent 渐变胶囊样式：padding + background(LinearGradient appAccent) + clipShape(Capsule)
    func accentCapsuleStyle(
        horizontalPadding: CGFloat = DesignSystem.medium,
        verticalPadding: CGFloat = DesignSystem.small,
        gradientEndOpacity: Double = DesignSystem.Opacity.prominent
    ) -> some View {
        modifier(AccentCapsuleModifier(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            gradientEndOpacity: gradientEndOpacity
        ))
    }
}

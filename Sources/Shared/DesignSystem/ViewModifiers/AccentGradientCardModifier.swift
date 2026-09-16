//
//  AccentGradientCardModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 共享层
//  核心职责：Accent 渐变边框卡片 ViewModifier，消除 Features 中重复的 padding+background(appAccent)+overlay(LinearGradient stroke) 链。
//

import SwiftUI

/// Accent 渐变边框卡片修饰符，消除重复的 padding+background(appAccent)+overlay(LinearGradient stroke) 链
struct AccentGradientCardModifier: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.largeRadius
    var backgroundOpacity: Double = DesignSystem.Opacity.atomic
    var borderWidth: CGFloat = SystemStroke.divider
    var borderOpacity: Double = DesignSystem.Opacity.medium

    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.appAccent.opacity(backgroundOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [.appAccent.opacity(borderOpacity), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
            )
    }
}

extension View {
    /// Accent 渐变边框卡片样式：padding + background(appAccent) + overlay(LinearGradient stroke)
    func accentGradientCardStyle(
        cornerRadius: CGFloat = DesignSystem.largeRadius,
        backgroundOpacity: Double = DesignSystem.Opacity.atomic,
        borderWidth: CGFloat = SystemStroke.divider,
        borderOpacity: Double = DesignSystem.Opacity.medium
    ) -> some View {
        modifier(AccentGradientCardModifier(
            cornerRadius: cornerRadius,
            backgroundOpacity: backgroundOpacity,
            borderWidth: borderWidth,
            borderOpacity: borderOpacity
        ))
    }
}

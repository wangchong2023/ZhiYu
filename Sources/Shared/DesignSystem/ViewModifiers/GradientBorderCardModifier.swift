//
//  GradientBorderCardModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 共享层
//  核心职责：渐变边框卡片 ViewModifier，消除 Features 中重复的 padding+background(appCard.ghost)+clipShape+overlay(LinearGradient stroke) 链。
//

import SwiftUI
import UFPDesignSystem

/// 渐变边框卡片修饰符，消除重复的 padding+background+clipShape+overlay(LinearGradient stroke) 链
struct GradientBorderCardModifier: ViewModifier {
    var padding: CGFloat = DesignTokens.Spacing.standardPadding
    var cornerRadius: CGFloat = DesignTokens.Spacing.standardRadius
    var backgroundOpacity: Double = DesignTokens.Opacity.ghost
    var gradientStartColor: Color = .appAccent
    var gradientStartOpacity: Double = DesignTokens.Opacity.disabled
    var borderWidth: CGFloat = DesignTokens.SystemStroke.divider

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.appCard.opacity(backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [gradientStartColor.opacity(gradientStartOpacity), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
            )
    }
}

extension View {
    /// 渐变边框卡片样式：padding + background(appCard) + clipShape + overlay(LinearGradient stroke)
    func gradientBorderCardStyle(
        padding: CGFloat = DesignTokens.Spacing.standardPadding,
        cornerRadius: CGFloat = DesignTokens.Spacing.standardRadius,
        backgroundOpacity: Double = DesignTokens.Opacity.ghost,
        gradientStartColor: Color = .appAccent,
        gradientStartOpacity: Double = DesignTokens.Opacity.disabled,
        borderWidth: CGFloat = DesignTokens.SystemStroke.divider
    ) -> some View {
        modifier(GradientBorderCardModifier(
            padding: padding,
            cornerRadius: cornerRadius,
            backgroundOpacity: backgroundOpacity,
            gradientStartColor: gradientStartColor,
            gradientStartOpacity: gradientStartOpacity,
            borderWidth: borderWidth
        ))
    }
}

//
//  CardStyleModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 共享层
//  核心职责：卡片样式 ViewModifier，消除 Features 中重复的 padding+background+clipShape 修饰符链。
//

import SwiftUI

/// 卡片样式修饰符，消除重复的 padding+background+clipShape(+overlay+stroke) 链
struct CardStyleModifier: ViewModifier {
    var horizontalPadding: CGFloat = DesignSystem.standardPadding
    var verticalPadding: CGFloat = SystemSpacing.elementLarge
    var backgroundOpacity: Double = DesignSystem.Opacity.dim
    var cornerRadius: CGFloat = DesignSystem.mediumRadius
    var showBorder: Bool = false
    var borderWidth: CGFloat = SystemStroke.divider

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Color.appCard.opacity(backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                Group {
                    if showBorder {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.appBorder.opacity(DesignSystem.Opacity.prominent), lineWidth: borderWidth)
                    }
                }
            )
    }
}

extension View {
    /// 标准卡片样式：padding + background + clipShape
    func cardStyle(
        horizontalPadding: CGFloat = DesignSystem.standardPadding,
        verticalPadding: CGFloat = SystemSpacing.elementLarge,
        backgroundOpacity: Double = DesignSystem.Opacity.dim,
        cornerRadius: CGFloat = DesignSystem.mediumRadius
    ) -> some View {
        modifier(CardStyleModifier(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            backgroundOpacity: backgroundOpacity,
            cornerRadius: cornerRadius
        ))
    }

    /// 带边框卡片样式：padding + background + clipShape + overlay(stroke)
    func borderedCardStyle(
        horizontalPadding: CGFloat = DesignSystem.standardPadding,
        verticalPadding: CGFloat = SystemSpacing.elementLarge,
        backgroundOpacity: Double = DesignSystem.Opacity.dim,
        cornerRadius: CGFloat = DesignSystem.mediumRadius,
        borderWidth: CGFloat = SystemStroke.divider
    ) -> some View {
        modifier(CardStyleModifier(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            backgroundOpacity: backgroundOpacity,
            cornerRadius: cornerRadius,
            showBorder: true,
            borderWidth: borderWidth
        ))
    }
}

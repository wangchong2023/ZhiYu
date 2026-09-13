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
    var borderColor: Color = .appBorder
    var borderOpacity: Double = DesignSystem.Opacity.prominent

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
                            .strokeBorder(borderColor.opacity(borderOpacity), lineWidth: borderWidth)
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
        borderWidth: CGFloat = SystemStroke.divider,
        borderColor: Color = .appBorder,
        borderOpacity: Double = DesignSystem.Opacity.prominent
    ) -> some View {
        modifier(CardStyleModifier(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            backgroundOpacity: backgroundOpacity,
            cornerRadius: cornerRadius,
            showBorder: true,
            borderWidth: borderWidth,
            borderColor: borderColor,
            borderOpacity: borderOpacity
        ))
    }

    /// 信息卡片样式：padding + frame(maxWidth) + background + clipShape + optional overlay(stroke)
    /// 用于实体/来源详情页的信息卡片展示
    func infoCardStyle(
        backgroundOpacity: Double = DesignSystem.Opacity.ghost,
        cornerRadius: CGFloat = DesignSystem.standardRadius,
        useBorder: Bool = false
    ) -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appCard.opacity(backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                Group {
                    if useBorder {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.appBorder, lineWidth: DesignSystem.borderWidth)
                    }
                }
            )
    }
}

/// 小卡片边框修饰符，消除跨文件的 cornerRadius+overlay(stroke) 重复
struct SmallCardBorderModifier: ViewModifier {
    let cornerRadius: CGFloat
    let strokeOpacity: Double

    func body(content: Content) -> some View {
        content
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.appBorder.opacity(strokeOpacity), lineWidth: SystemStroke.divider)
            )
    }
}

extension View {
    /// 应用小卡片边框样式（默认 SystemRadius.small + Opacity.subtle）
    func smallCardBorder(cornerRadius: CGFloat = SystemRadius.small, strokeOpacity: Double = DesignSystem.Opacity.subtle) -> some View {
        modifier(SmallCardBorderModifier(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }
}

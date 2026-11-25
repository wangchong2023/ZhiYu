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
public struct CardStyleModifier: ViewModifier {
    public var horizontalPadding: CGFloat = DesignTokens.Spacing.standardPadding
    public var verticalPadding: CGFloat = DesignTokens.SystemSpacing.elementLarge
    public var backgroundOpacity: Double = DesignTokens.Opacity.dim
    public var cornerRadius: CGFloat = DesignTokens.Spacing.mediumRadius
    public var showBorder: Bool = false
    public var borderWidth: CGFloat = DesignTokens.SystemStroke.divider
    public var borderColor: Color = .appBorder
    public var borderOpacity: Double = DesignTokens.Opacity.prominent

    public init(
        horizontalPadding: CGFloat = DesignTokens.Spacing.standardPadding,
        verticalPadding: CGFloat = DesignTokens.SystemSpacing.elementLarge,
        backgroundOpacity: Double = DesignTokens.Opacity.dim,
        cornerRadius: CGFloat = DesignTokens.Spacing.mediumRadius,
        showBorder: Bool = false,
        borderWidth: CGFloat = DesignTokens.SystemStroke.divider,
        borderColor: Color = .appBorder,
        borderOpacity: Double = DesignTokens.Opacity.prominent
    ) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.backgroundOpacity = backgroundOpacity
        self.cornerRadius = cornerRadius
        self.showBorder = showBorder
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.borderOpacity = borderOpacity
    }

    public func body(content: Content) -> some View {
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

public extension View {
    /// 标准卡片样式：padding + background + clipShape
    func cardStyle(
        horizontalPadding: CGFloat = DesignTokens.Spacing.standardPadding,
        verticalPadding: CGFloat = DesignTokens.SystemSpacing.elementLarge,
        backgroundOpacity: Double = DesignTokens.Opacity.dim,
        cornerRadius: CGFloat = DesignTokens.Spacing.mediumRadius
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
        horizontalPadding: CGFloat = DesignTokens.Spacing.standardPadding,
        verticalPadding: CGFloat = DesignTokens.SystemSpacing.elementLarge,
        backgroundOpacity: Double = DesignTokens.Opacity.dim,
        cornerRadius: CGFloat = DesignTokens.Spacing.mediumRadius,
        borderWidth: CGFloat = DesignTokens.SystemStroke.divider,
        borderColor: Color = .appBorder,
        borderOpacity: Double = DesignTokens.Opacity.prominent
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
        backgroundOpacity: Double = DesignTokens.Opacity.ghost,
        cornerRadius: CGFloat = DesignTokens.Spacing.standardRadius,
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
                            .stroke(Color.appBorder, lineWidth: DesignTokens.Spacing.borderWidth)
                    }
                }
            )
    }
}

/// 小卡片边框修饰符，消除跨文件的 cornerRadius+overlay(stroke) 重复
public struct SmallCardBorderModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let strokeOpacity: Double

    public init(
        cornerRadius: CGFloat = DesignTokens.SystemRadius.small,
        strokeOpacity: Double = DesignTokens.Opacity.subtle
    ) {
        self.cornerRadius = cornerRadius
        self.strokeOpacity = strokeOpacity
    }

    public nonisolated func body(content: Content) -> some View {
        content
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.appBorder.opacity(strokeOpacity), lineWidth: DesignTokens.SystemStroke.divider)
            )
    }
}

public extension View {
    /// 应用小卡片边框样式（默认 DesignTokens.SystemRadius.small + Opacity.subtle）
    nonisolated func smallCardBorder(cornerRadius: CGFloat = DesignTokens.SystemRadius.small, strokeOpacity: Double = DesignTokens.Opacity.subtle) -> some View {
        modifier(SmallCardBorderModifier(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }
}

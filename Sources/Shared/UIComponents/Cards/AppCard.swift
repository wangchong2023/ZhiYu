//
//  AppCard.swift
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

// MARK: - App Card Modifier

/// 应用卡片背景的视图修饰符
/// 负责注入一致的内边距、背景色及圆角样式。
public struct AppCardModifier: ViewModifier {
    public var cornerRadiusToken: DesignTokens.RadiusToken = .card
    public var paddingToken: DesignTokens.SpacingToken = .standardPadding
    public var backgroundColor: Color = .appCard

    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    public func body(content: Content) -> some View {
        content
            .appPadding(.all, paddingToken)
            .background(backgroundColor)
            .appCornerRadius(cornerRadiusToken)
    }
}

// MARK: - App Card (Container)

/// 标准卡片容器组件
/// 提供符合设计系统的阴影、圆角及背景封装。
public struct AppCard<Content: View>: View {
    public let content: Content
    public var cornerRadiusToken: DesignTokens.RadiusToken = .card
    public var paddingToken: DesignTokens.SpacingToken = .standardPadding

    public init(
        cornerRadiusToken: DesignTokens.RadiusToken = .card,
        paddingToken: DesignTokens.SpacingToken = .standardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadiusToken = cornerRadiusToken
        self.paddingToken = paddingToken
        self.content = content()
    }

    /// 向后兼容原有 CGFloat 参数的构造函数。
    public init(
        cornerRadius: CGFloat,
        padding: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadiusToken = AppCardTokenMapper.radiusToken(for: cornerRadius)
        
        self.paddingToken = AppCardTokenMapper.spacingToken(for: padding)

        self.content = content()
    }

    public var body: some View {
        content
            .appPadding(.all, paddingToken)
            .background(Color.appCard)
            .appCornerRadius(cornerRadiusToken)
    }
}

// MARK: - App Bordered Card

/// 带描边效果的卡片
/// 适用于需要视觉分割或引导点击的入口区域。
public struct AppBorderedCard<Content: View>: View {
    public let content: Content
    public var cornerRadius: CGFloat = DesignTokens.Spacing.cardRadius
    public var borderColor: Color = .appBorder

    public init(
        cornerRadius: CGFloat = DesignTokens.Spacing.cardRadius,
        borderColor: Color = .appBorder,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.vertical, DesignTokens.Spacing.standardPadding)
            .padding(.horizontal, DesignTokens.Spacing.medium)
            .frame(maxWidth: .infinity)
            .appCardClip(cornerRadius: cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: DesignTokens.Spacing.borderWidth)
            )
    }
}

// MARK: - App Glass Card

/// 玻璃拟态风格卡片
/// 使用系统材质 (Material) 结合阴影实现高阶视觉层次感。
public struct AppGlassCard<Content: View>: View {
    public let content: Content
    public var cornerRadius: CGFloat = DesignTokens.Spacing.cardRadius
    public var isHighlighted: Bool = false

    public init(
        cornerRadius: CGFloat = DesignTokens.Spacing.cardRadius,
        isHighlighted: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
        self.content = content()
    }

    public var body: some View {
        content
            .padding(DesignTokens.Spacing.Layout.cardContentPadding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.appCard.opacity(DesignTokens.Colors.Opacity.translucentOpacity))
                    if isHighlighted {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.appAccent.opacity(DesignTokens.Colors.Opacity.accentStrokeOpacity), lineWidth: DesignTokens.SystemStroke.border)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: .primary.opacity(isHighlighted ? DesignTokens.SystemOpacity.glass : DesignTokens.SystemOpacity.ghost),
                radius: isHighlighted ? DesignTokens.Spacing.Decorator.shadowRadiusLarge : DesignTokens.Spacing.Decorator.shadowRadiusSmall, 
                x: 0, 
                y: isHighlighted ? DesignTokens.Spacing.Decorator.shadowOffsetYLarge : DesignTokens.Spacing.Decorator.shadowOffsetYSmall
            )
    }
}

// MARK: - App Card Accent

/// 卡片顶部的装饰性条纹
/// 用于通过颜色标识卡片类别或状态。
public struct AppCardAccent: View {
    public var color: Color = .appAccent
    public var height: CGFloat = DesignTokens.Spacing.Decorator.accentLineWidth

    public init(color: Color = .appAccent, height: CGFloat = DesignTokens.Spacing.Decorator.accentLineWidth) {
        self.color = color
        self.height = height
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Spacing.tiny)
            .fill(color)
            .frame(height: height)
    }
}

// MARK: - View Extension

public extension View {
    /// 应用标准卡片背景，使用强类型设计系统令牌。
    func appCard(
        cornerRadiusToken: DesignTokens.RadiusToken = .card, 
        paddingToken: DesignTokens.SpacingToken = .standardPadding
    ) -> some View {
        modifier(AppCardModifier(cornerRadiusToken: cornerRadiusToken, paddingToken: paddingToken))
    }
    
    /// 向后兼容原有 CGFloat 参数的卡片背景应用扩展。
    func appCard(
        cornerRadius: CGFloat, 
        padding: CGFloat = DesignTokens.Spacing.Layout.cardContentPadding
    ) -> some View {
        let cornerToken = AppCardTokenMapper.radiusToken(for: cornerRadius)
        let padToken = AppCardTokenMapper.spacingToken(for: padding)

        return modifier(AppCardModifier(cornerRadiusToken: cornerToken, paddingToken: padToken))
    }
}

// MARK: - SpacingToken 映射辅助
private enum AppCardTokenMapper {
    /// CGFloat padding → SpacingToken（消除两处重复的三元表达式链）
    static func spacingToken(for padding: CGFloat) -> DesignTokens.SpacingToken {
        if padding == DesignTokens.Spacing.atomic { return .atomic }
        if padding == DesignTokens.Spacing.tiny { return .tiny }
        if padding == DesignTokens.Spacing.small { return .small }
        if padding == DesignTokens.Spacing.medium { return .medium }
        if padding == DesignTokens.Spacing.Layout.cardContentPadding { return .standardPadding }
        if padding == DesignTokens.Spacing.giant { return .giant }
        if padding == DesignTokens.Spacing.huge { return .huge }
        return .standardPadding
    }

    /// CGFloat cornerRadius → RadiusToken（消除两处重复的三元表达式链）
    static func radiusToken(for cornerRadius: CGFloat) -> DesignTokens.RadiusToken {
        if cornerRadius == DesignTokens.Spacing.microRadius { return .micro }
        if cornerRadius == DesignTokens.Spacing.smallRadius { return .small }
        if cornerRadius == DesignTokens.Spacing.mediumRadius { return .medium }
        if cornerRadius == DesignTokens.Spacing.largeRadius { return .large }
        if cornerRadius == DesignTokens.Spacing.chipRadius { return .chip }
        return .card
    }
}

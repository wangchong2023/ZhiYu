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

// MARK: - App Card Modifier

/// 应用卡片背景的视图修饰符
/// 负责注入一致的内边距、背景色及圆角样式。
public struct AppCardModifier: ViewModifier {
    public var cornerRadiusToken: DesignSystem.RadiusToken = .card
    public var paddingToken: DesignSystem.SpacingToken = .standardPadding
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
    public var cornerRadiusToken: DesignSystem.RadiusToken = .card
    public var paddingToken: DesignSystem.SpacingToken = .standardPadding

    public init(
        cornerRadiusToken: DesignSystem.RadiusToken = .card,
        paddingToken: DesignSystem.SpacingToken = .standardPadding,
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
        self.cornerRadiusToken = cornerRadius == Spacing.microRadius ? .micro :
                                 cornerRadius == Spacing.smallRadius ? .small :
                                 cornerRadius == Spacing.mediumRadius ? .medium :
                                 cornerRadius == Spacing.largeRadius ? .large :
                                 cornerRadius == Spacing.chipRadius ? .chip : .card
        
        self.paddingToken = padding == Spacing.atomic ? .atomic :
                            padding == Spacing.tiny ? .tiny :
                            padding == Spacing.small ? .small :
                            padding == Spacing.medium ? .medium :
                            padding == Spacing.Layout.cardContentPadding ? .standardPadding :
                            padding == Spacing.giant ? .giant :
                            padding == Spacing.huge ? .huge : .standardPadding
        
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
    public var cornerRadius: CGFloat = Spacing.cardRadius
    public var borderColor: Color = .appBorder

    public init(
        cornerRadius: CGFloat = Spacing.cardRadius,
        borderColor: Color = .appBorder,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.vertical, Spacing.standardPadding)
            .padding(.horizontal, Spacing.medium)
            .frame(maxWidth: .infinity)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: Spacing.borderWidth)
            )
    }
}

// MARK: - App Glass Card

/// 玻璃拟态风格卡片
/// 使用系统材质 (Material) 结合阴影实现高阶视觉层次感。
public struct AppGlassCard<Content: View>: View {
    public let content: Content
    public var cornerRadius: CGFloat = Spacing.cardRadius
    public var isHighlighted: Bool = false

    public init(
        cornerRadius: CGFloat = Spacing.cardRadius,
        isHighlighted: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Spacing.Layout.cardContentPadding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.appCard.opacity(DesignSystem.translucentOpacity))
                    if isHighlighted {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.appAccent.opacity(DesignSystem.accentStrokeOpacity), lineWidth: SystemStroke.border)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: .primary.opacity(isHighlighted ? SystemOpacity.glass : SystemOpacity.ghost * 0.75),
                radius: isHighlighted ? Spacing.Decorator.shadowRadiusLarge : Spacing.Decorator.shadowRadiusSmall, 
                x: 0, 
                y: isHighlighted ? Spacing.Decorator.shadowOffsetYLarge : Spacing.Decorator.shadowOffsetYSmall
            )
    }
}

// MARK: - App Card Accent

/// 卡片顶部的装饰性条纹
/// 用于通过颜色标识卡片类别或状态。
public struct AppCardAccent: View {
    public var color: Color = .appAccent
    public var height: CGFloat = Spacing.Decorator.accentLineWidth

    public init(color: Color = .appAccent, height: CGFloat = Spacing.Decorator.accentLineWidth) {
        self.color = color
        self.height = height
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: Spacing.tiny)
            .fill(color)
            .frame(height: height)
    }
}

// MARK: - View Extension

public extension View {
    /// 应用标准卡片背景，使用强类型设计系统令牌。
    func appCard(
        cornerRadiusToken: DesignSystem.RadiusToken = .card, 
        paddingToken: DesignSystem.SpacingToken = .standardPadding
    ) -> some View {
        modifier(AppCardModifier(cornerRadiusToken: cornerRadiusToken, paddingToken: paddingToken))
    }
    
    /// 向后兼容原有 CGFloat 参数的卡片背景应用扩展。
    func appCard(
        cornerRadius: CGFloat, 
        padding: CGFloat = Spacing.Layout.cardContentPadding
    ) -> some View {
        let cornerToken: DesignSystem.RadiusToken = cornerRadius == Spacing.microRadius ? .micro :
                                                    cornerRadius == Spacing.smallRadius ? .small :
                                                    cornerRadius == Spacing.mediumRadius ? .medium :
                                                    cornerRadius == Spacing.largeRadius ? .large :
                                                    cornerRadius == Spacing.chipRadius ? .chip : .card
        
        let padToken: DesignSystem.SpacingToken = padding == Spacing.atomic ? .atomic :
                                                  padding == Spacing.tiny ? .tiny :
                                                  padding == Spacing.small ? .small :
                                                  padding == Spacing.medium ? .medium :
                                                  padding == Spacing.Layout.cardContentPadding ? .standardPadding :
                                                  padding == Spacing.giant ? .giant :
                                                  padding == Spacing.huge ? .huge : .standardPadding
        
        return modifier(AppCardModifier(cornerRadiusToken: cornerToken, paddingToken: padToken))
    }
}

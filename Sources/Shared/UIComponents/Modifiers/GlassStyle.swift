//
//  GlassStyle.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

/// 统一的玻璃卡片视图修饰符
/// 使用系统材质 (Material) 结合自定义不透明度实现通用的玻璃质感背景。
public struct GlassCardModifier: ViewModifier {
    // MARK: - Properties
    
    /// 材质的不透明度
    public let opacity: Double
    /// 圆角半径
    public let cornerRadius: CGFloat
    
    // MARK: - Initialization
    
    /// 初始化玻璃卡片修饰符
    /// - Parameters:
    ///   - opacity: 默认 1.0
    ///   - cornerRadius: 默认使用全局卡片圆角规范
    public init(opacity: Double = 1.0, cornerRadius: CGFloat = Spacing.cardRadius) {
        self.opacity = opacity
        self.cornerRadius = cornerRadius
    }
    
    // MARK: - Body
    
    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(opacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.appBorder.opacity(DesignSystem.Opacity.disabled), lineWidth: 0.5)
            )
            .shadow(color: Color.theme.black.opacity(DesignSystem.Opacity.ghost), radius: 10, x: 0, y: 5)
    }
}

// MARK: - View 扩展

public extension View {
    /// 应用玻璃拟态卡片样式
    /// - Parameters:
    ///   - opacity: 材质不透明度
    ///   - cornerRadius: 圆角半径
    /// - Returns: 装饰后的视图
    func appGlassCardStyle(opacity: Double = 1.0, cornerRadius: CGFloat = Spacing.cardRadius) -> some View {
        self.modifier(GlassCardModifier(opacity: opacity, cornerRadius: cornerRadius))
    }
    
    /// 应用标准卡片容器样式
    /// 提供统一的内边距、背景和阴影效果。
    /// - Parameter cornerRadius: 圆角半径
    /// - Returns: 装饰后的视图
    func appCardStyle(cornerRadius: CGFloat = Spacing.cardRadius) -> some View {
        self.padding(Spacing.large)
            .background(.ultraThinMaterial)
            .background(Color.appCard.opacity(DesignSystem.Opacity.overlay))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.appBorder.opacity(DesignSystem.Opacity.disabled), lineWidth: Spacing.borderWidth)
            )
            .shadow(color: Color.theme.black.opacity(DesignSystem.Opacity.ghost), radius: 10, x: 0, y: 5)
    }
    
    /// 应用通用页面容器样式
    /// - Parameters:
    ///   - background: 背景颜色
    ///   - borderColor: 边框颜色
    ///   - cornerRadius: 圆角半径
    ///   - padding: 是否添加标准内边距
    /// - Returns: 装饰后的视图
    func appContainer(
        background: Color = .appCard,
        borderColor: Color = .appBorder,
        cornerRadius: CGFloat = Spacing.cardRadius,
        padding: Bool = true
    ) -> some View {
        self.padding(padding ? Spacing.standardPadding : 0)
            .background(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial).opacity(DesignSystem.Opacity.disabled) // 降低材质干扰
                    background.opacity(UIConstants.backgroundOpacity) // 优化通透度
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor.opacity(DesignSystem.Opacity.medium), lineWidth: 0.5) // 稍微增强边框，匹配任务中心
            )
            .shadow(color: Color.theme.black.opacity(DesignSystem.Opacity.faint), radius: 10, x: 0, y: 5)
    }
    
    /// 仪表盘指标卡片风格 (Metric Card Style)
    /// 带有微弱的渐变效果和加大的圆角规范。
    /// - Parameters:
    ///   - color: 强调色背景
    ///   - cornerRadius: 默认使用仪表盘专用圆角
    /// - Returns: 装饰后的视图
    func appMetricCardStyle(color: Color = .appAccent, cornerRadius: CGFloat = Spacing.Metrics.dashboardRadius) -> some View {
        self.background(.ultraThinMaterial)
            .background(
                ZStack {
                    Color.appCard.opacity(DesignSystem.Opacity.prominent) // 提高亮度
                    LinearGradient(
                        colors: [color.opacity(DesignSystem.Opacity.glass), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color.opacity(DesignSystem.Opacity.medium), lineWidth: 0.5) // 使用强调色淡边框
            )
            .shadow(color: Color.theme.black.opacity(DesignSystem.Opacity.atomic), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 统一列表行毛玻璃背景

/// 统一的列表行磨砂玻璃背景组件
/// 使用系统的超薄材质 (.ultraThinMaterial) 叠加轻微微透的强调底色，保障其在深色模式与浅色模式下均具有极佳的视觉可读性与高级感
public struct AppListRowBackground: View {
    // MARK: - 初始化
    
    /// 初始化磨砂玻璃背景组件
    public init() {}
    
    // MARK: - 视图主体
    
    public var body: some View {
        Color.appCard.opacity(DesignSystem.subtleOpacity)
            .background(.ultraThinMaterial)
    }
}

/// 列表行磨砂玻璃背景修饰符
public struct AppListRowBackgroundModifier: ViewModifier {
    // MARK: - 初始化
    
    /// 初始化修饰符
    public init() {}
    
    // MARK: - 视图转换
    
    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    public func body(content: Content) -> some View {
        content
            .listRowBackground(AppListRowBackground())
    }
}

public extension View {
    /// 为列表项或 Section 统一应用高级磨砂玻璃背景样式
    /// - Returns: 挂载了磨砂玻璃背景后的视图
    func appListRowBackground() -> some View {
        self.modifier(AppListRowBackgroundModifier())
    }
}

// MARK: - 常量
private enum UIConstants {
    static let backgroundOpacity: Double = SystemOpacity.strong
}

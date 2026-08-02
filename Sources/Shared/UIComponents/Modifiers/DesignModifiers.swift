//
//  DesignModifiers.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

// MARK: - 1. 弹性物理悬停修饰器

/// 弹性物理悬停微缩放修饰符
struct ScaleOnHoverModifier: ViewModifier {
    /// 悬停动画的目标缩放比例
    let scale: CGFloat
    
    /// 本地悬停激活状态
    @State private var isHovered = false
    
    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        #if os(watchOS)
        content
        #else
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .onHover { hovering in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                    isHovered = hovering
                }
            }
        #endif
    }
}

// MARK: - 2. 高保真弥散软阴影修饰器

/// 高保真弥散环境光晕多重软阴影修饰符
struct PremiumAmbientShadowModifier: ViewModifier {
    /// 阴影的底色
    let color: Color
    
    /// 物理扩散半径
    let radius: CGFloat
    
    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        content
            // 第一层：大范围微弱漫反射阴影，确立环境光底色
            .shadow(color: color.opacity(DesignSystem.Opacity.ghost), radius: radius, x: 0, y: radius * 0.4)
            // 第二层：小范围紧致遮蔽阴影，确立物理接缝立体感
            .shadow(color: color.opacity(DesignSystem.Opacity.faint), radius: radius * 0.4, x: 0, y: radius * 0.15)
    }
}

// MARK: - 3. 霓虹渐变呼吸边框修饰器

/// 霓虹渐变高亮呼吸外框修饰符
struct GlowingNeonBorderModifier: ViewModifier {
    /// 是否开启霓虹高光
    let isGlowing: Bool
    
    /// 覆盖圆角弧度
    let cornerRadius: CGFloat
    
    /// 自定义渐变色阵列
    let gradientColors: [Color]
    
    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: isGlowing ? gradientColors : [Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isGlowing ? 1.5 : 0
                    )
                    // 渐变外光圈发光，营造呼吸高亮
                    .shadow(color: isGlowing ? (gradientColors.first ?? .blue).opacity(DesignSystem.Opacity.disabled) : .clear, radius: isGlowing ? 6 : 0)
                    .animation(.easeInOut(duration: 0.35), value: isGlowing)
            )
    }
}

// MARK: - View 语义链式调用扩展

public extension View {
    /// 注入基于设计系统的原子内边距修饰器
    /// - Parameters:
    ///   - edges: 内边距作用方向，默认全部边缘
    ///   - token: 强类型间距令牌
    func appPadding(_ edges: Edge.Set = .all, _ token: DesignSystem.SpacingToken) -> some View {
        self.padding(edges, token.value)
    }
    
    /// 注入基于设计系统的原子圆角裁切修饰器
    /// - Parameter token: 强类型圆角令牌
    func appCornerRadius(_ token: DesignSystem.RadiusToken) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: token.value))
    }

    /// 注入支持高级阻尼弹性悬停物理微动效
    /// - Parameter scale: 悬停时的缩放比例（默认 1.025）
    func scaleOnHover(scale: CGFloat = 1.025) -> some View {
        #if os(watchOS)
        self
        #else
        self.modifier(ScaleOnHoverModifier(scale: scale))
        #endif
    }
    
    /// 注入多层低透明度环境光晕漫反射阴影，营造绝佳的拟物毛玻璃立体悬浮度
    /// - Parameters:
    ///   - color: 阴影颜色（默认黑色）
    ///   - radius: 阴影发散半径（默认 12）
    func premiumAmbientShadow(color: Color = .black, radius: CGFloat = 12) -> some View {
        self.modifier(PremiumAmbientShadowModifier(color: color, radius: radius))
    }
    
    /// 注入霓虹渐变高亮呼吸外框，用作焦点元素和 Aha Card 激活的微动效容器
    /// - Parameters:
    ///   - isGlowing: 是否亮起
    ///   - cornerRadius: 圆角弧度（默认 12）
    ///   - gradientColors: 渐变色组合，默认采用 [蓝色, 紫色, 青色] 现代高阶配色
    func glowingNeonBorder(
        isGlowing: Bool = true,
        cornerRadius: CGFloat = 12,
        gradientColors: [Color] = [.blue, .purple, .init(red: 0.0, green: 0.8, blue: 0.9)]
    ) -> some View {
        self.modifier(GlowingNeonBorderModifier(isGlowing: isGlowing, cornerRadius: cornerRadius, gradientColors: gradientColors))
    }
    
    @ViewBuilder
    /// 跨平台 NavigationBarTitleDisplayMode 修饰符，自动在不支持的平台降级屏蔽
    func appNavigationBarTitleDisplayMode(_ mode: NavigationBarItem.TitleDisplayMode) -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(mode)
        #else
        self
        #endif
    }
}

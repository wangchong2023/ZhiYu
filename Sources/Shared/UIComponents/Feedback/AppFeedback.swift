//
//  AppFeedback.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

// MARK: - App Pulse Dot

/// 脉冲式状态指示点
/// 通过缩放和透明度变化实现呼吸感反馈。
public struct AppPulseDot: View {
    public var color: Color = .appAccent
    public var size: CGFloat = Spacing.small

    @State private var isPulsing = false

    public init(color: Color = .appAccent, size: CGFloat = Spacing.small) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(DesignSystem.Opacity.shadow))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(isPulsing ? Spacing.Decorator.pulseScale : 1.0)
                .opacity(isPulsing ? 0 : 1)

            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeOut(duration: Animations.Decorator.pulseDuration).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - App Shimmer

/// 闪烁加载背景
/// 通过渐变色偏移实现骨架屏的流光效果。
public struct AppShimmer: View {
    @State private var phase: CGFloat = 0

    public init() {}

    public var body: some View {
        LinearGradient(
            colors: [
                .clear,
                Color.appAccent.opacity(DesignSystem.Opacity.glass),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: phase)
        .onAppear {
            ShimmerAnimation.startLinear { phase = Animations.Decorator.shimmerPhaseShift }
        }
    }
}

// MARK: - Shimmer Modifier

/// 流光效果视图修饰符
public struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -Animations.Decorator.shimmerPhaseShift / 2

    public init() {}

    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.theme.white.opacity(DesignSystem.Opacity.medium),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * Animations.Decorator.shimmerWidthRatio)
                    .offset(x: phase)
                    .onAppear {
                        ShimmerAnimation.startLinear { phase = geometry.size.width * Animations.Decorator.shimmerEndRatio }
                    }
                }
            )
            .clipped()
    }
}

// MARK: - App Skeleton

/// 骨架屏占位组件
public struct AppSkeleton: View {
    public var width: CGFloat?
    public var height: CGFloat = Spacing.large
    public var cornerRadius: CGFloat = Spacing.tiny

    public init(width: CGFloat? = nil, height: CGFloat = Spacing.large, cornerRadius: CGFloat = Spacing.tiny) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.appSecondary.opacity(DesignSystem.Opacity.glass))
            .frame(width: width, height: height)
            .shimmerApp()
    }
}

// MARK: - App Success Banner

/// 成功提示横幅
public struct AppSuccessBanner: View {
    public let message: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(message: String) {
        self.message = message
    }

    private var bannerFont: Font {
        AdaptiveTypography.adaptiveSecondaryFont(horizontalSizeClass: horizontalSizeClass)
    }

    public var body: some View {
        HStack(spacing: Spacing.tiny + Spacing.atomic) { // 6
            Image(systemName: DesignSystem.Icons.checkCircle)
                .foregroundStyle(Color.theme.green)
            Text(message)
                .font(bannerFont)
                .foregroundStyle(Color.theme.green)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.theme.green.opacity(Colors.glassOpacity))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.standardRadius))
    }
}

// MARK: - App Glow

/// 图标光晕效果
public struct AppGlow: View {
    public let icon: String
    public var color: Color = .appAccent
    public var size: CGFloat = Spacing.huge

    public init(icon: String, color: Color = .appAccent, size: CGFloat = Spacing.huge) {
        self.icon = icon
        self.color = color
        self.size = size
    }

    public var body: some View {
        ZStack {
            // 外层光晕
            Circle()
                .fill(color.opacity(DesignSystem.Opacity.glass))
                .frame(width: size * Spacing.Decorator.glowScaleLarge, height: size * Spacing.Decorator.glowScaleLarge)
                .blur(radius: Spacing.Decorator.glowBlurMedium)

            // 内层光晕
            Circle()
                .fill(color.opacity(DesignSystem.Opacity.medium))
                .frame(width: size * Spacing.Decorator.glowScaleMedium, height: size * Spacing.Decorator.glowScaleMedium)
                .blur(radius: Spacing.Decorator.glowBlurSmall)

            // 中心图标
            Image(systemName: icon)
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

// MARK: - View Extension

public extension View {
    /// 应用流光加载动画
    func shimmerApp() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - 自适应排版辅助

/// 根据水平尺寸类选择字号，消除 AppChips / AppFeedback 中重复的 `horizontalSizeClass == .regular ? Typography.secondaryFont : Typography.captionFont` 三元表达式。
enum AdaptiveTypography {
    static func adaptiveSecondaryFont(horizontalSizeClass: UserInterfaceSizeClass?) -> Font {
        horizontalSizeClass == .regular ? Typography.secondaryFont : Typography.captionFont
    }
}

// MARK: - 流光动画共享辅助

/// 统一的线性流光动画启动器，消除 AppShimmer / ShimmerModifier 两处重复的 withAnimation + shimmerDuration + repeatForever 链。
/// - Parameter body: 动画驱动相位变化的闭包
enum ShimmerAnimation {
    /// @PR-03: 使用高性能线性动画减少主线程压力
    static func startLinear(body: @escaping () -> Void) {
        withAnimation(.linear(duration: Animations.Decorator.shimmerDuration).repeatForever(autoreverses: false), body)
    }
}

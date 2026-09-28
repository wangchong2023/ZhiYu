//
//  DesignSystem+Decorator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：设计系统令牌：颜色、排版、间距、动画、图标等可视化常量。
//
import SwiftUI
import CoreGraphics
import UFPDesignSystem

extension DesignSystem {

    // MARK: - 17. 视觉装饰模式 (Decorator)
    public enum Decorator {
        public static let shadowRadiusSmall: CGFloat = DesignTokens.Spacing.Decorator.shadowRadiusSmall
        public static let shadowRadiusLarge: CGFloat = DesignTokens.Spacing.Decorator.shadowRadiusLarge
        public static let shadowOffsetYSmall: CGFloat = DesignTokens.Spacing.Decorator.shadowOffsetYSmall
        public static let shadowOffsetYLarge: CGFloat = DesignTokens.Spacing.Decorator.shadowOffsetYLarge
        public static let shimmerPhaseShift: CGFloat = DesignTokens.Animations.Decorator.shimmerPhaseShift
        public static let shimmerDuration: Double = DesignTokens.Animations.Decorator.shimmerDuration
        public static let shimmerWidthRatio: CGFloat = DesignTokens.Animations.Decorator.shimmerWidthRatio
        public static let shimmerEndRatio: CGFloat = DesignTokens.Animations.Decorator.shimmerEndRatio
        public static let glowScaleMedium: CGFloat = DesignTokens.Spacing.Decorator.glowScaleMedium
        public static let glowScaleLarge: CGFloat = DesignTokens.Spacing.Decorator.glowScaleLarge
        public static let glowBlurSmall: CGFloat = DesignTokens.Spacing.Decorator.glowBlurSmall
        public static let glowBlurMedium: CGFloat = DesignTokens.Spacing.Decorator.glowBlurMedium
        public static let pulseScale: CGFloat = DesignTokens.Spacing.Decorator.pulseScale
        public static let pulseDuration: Double = DesignTokens.Animations.Decorator.pulseDuration
        public static let accentLineWidth: CGFloat = DesignTokens.Spacing.Decorator.accentLineWidth
        public static let badgeMinSize: CGFloat = DesignTokens.Spacing.Decorator.badgeMinSize
        public static let desktopSheetMinWidth: CGFloat = DesignTokens.Spacing.Decorator.desktopSheetMinWidth
        public static let desktopSheetMinHeight: CGFloat = DesignTokens.Spacing.Decorator.desktopSheetMinHeight
    }
}

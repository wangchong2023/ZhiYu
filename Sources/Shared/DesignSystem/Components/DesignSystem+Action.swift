//
//  DesignSystem+Action.swift
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

    // MARK: - 5. 交互模式 (Action)
    public enum Action {
        public static let buttonHeight: CGFloat = DesignTokens.Spacing.Action.buttonHeight
        public static let compactButtonHeight: CGFloat = DesignTokens.Spacing.Action.compactButtonHeight
        public static let capsuleHeight: CGFloat = DesignTokens.Spacing.Action.capsuleHeight
        public static let inputFieldHeight: CGFloat = DesignTokens.Spacing.Action.inputFieldHeight
        public static let minTouchTarget: CGFloat = DesignTokens.Spacing.Action.minTouchTarget
        public static let inputBarHeight: CGFloat = DesignTokens.Spacing.Action.inputBarHeight
        public static let pressScale: CGFloat = DesignTokens.Spacing.Action.pressScale
        public static let animationDuration: Double = DesignTokens.Spacing.Action.animationDuration
        public static let buttonSpacing: CGFloat = DesignTokens.Spacing.Action.buttonSpacing
        public static let iconSize: CGFloat = DesignTokens.Spacing.Action.iconSize
        public static let smallIconSize: CGFloat = DesignTokens.Spacing.Action.smallIconSize
        public static let largeIconSize: CGFloat = DesignTokens.Spacing.Action.largeIconSize
        public static let backButtonWidth: CGFloat = DesignTokens.Spacing.Action.backButtonWidth
    }
}

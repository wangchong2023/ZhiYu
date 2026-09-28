//
//  DesignSystem+Timeline.swift
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

    // MARK: - 7. 轴线模式 (Timeline)
    public enum Timeline {
        public static let emptyIconSize: CGFloat = DesignTokens.Spacing.Timeline.emptyIconSize
        public static let indicatorSize: CGFloat = DesignTokens.Spacing.Timeline.indicatorSize
        public static let detailHorizontalPadding: CGFloat = DesignTokens.Spacing.Timeline.detailHorizontalPadding
        public static let detailVerticalPadding: CGFloat = DesignTokens.Spacing.Timeline.detailVerticalPadding
        public static let indentPadding: CGFloat = DesignTokens.Spacing.Timeline.indentPadding
        public static let rowVerticalPadding: CGFloat = DesignTokens.Spacing.Timeline.rowVerticalPadding
        public static let iconCircleSize: CGFloat = DesignTokens.Spacing.Timeline.iconCircleSize
    }
}

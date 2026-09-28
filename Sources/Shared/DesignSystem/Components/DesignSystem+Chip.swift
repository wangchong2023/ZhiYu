//
//  DesignSystem+Chip.swift
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

    // MARK: - 15. 碎片模式 (Chip)
    public enum Chip {
        public static let horizontalPadding: CGFloat = DesignTokens.Spacing.Chip.horizontalPadding
        public static let verticalPadding: CGFloat = DesignTokens.Spacing.Chip.verticalPadding
        public static let spacing: CGFloat = DesignTokens.Spacing.Chip.spacing
        public static let iconSpacing: CGFloat = DesignTokens.Spacing.Chip.iconSpacing
        public static let cornerRadius: CGFloat = DesignTokens.Spacing.Chip.cornerRadius
    }
}

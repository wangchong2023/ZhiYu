//
//  DesignSystem+CompositeRow.swift
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

    // MARK: - 10. 复合行模式 (CompositeRow)
    public enum CompositeRow {
        public static let spacing: CGFloat = DesignTokens.Spacing.CompositeRow.spacing
        public static let cornerRadius: CGFloat = DesignTokens.Spacing.CompositeRow.cornerRadius
        public static let iconBoxSize: CGFloat = DesignTokens.Spacing.CompositeRow.iconBoxSize
        public static let actionAreaWidth: CGFloat = DesignTokens.Spacing.CompositeRow.actionAreaWidth
        public static let indicatorWidth: CGFloat = DesignTokens.Spacing.CompositeRow.indicatorWidth
    }
}

//
//  DesignSystem+List.swift
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

    // MARK: - 14. 列表模式 (List)
    public enum List {
        public static let rowVerticalPadding: CGFloat = DesignTokens.Spacing.List.rowVerticalPadding
        public static let rowHorizontalPadding: CGFloat = DesignTokens.Spacing.List.rowHorizontalPadding
        public static let rowSpacing: CGFloat = DesignTokens.Spacing.List.rowSpacing
        public static let rowRadius: CGFloat = DesignTokens.Spacing.List.rowRadius
    }
}

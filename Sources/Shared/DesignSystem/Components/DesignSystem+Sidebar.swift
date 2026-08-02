//
//  DesignSystem+Sidebar.swift
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

extension DesignSystem {

    // MARK: - 16. 侧边栏模式 (Sidebar)
    public enum Sidebar {
        public static let rowSpacing: CGFloat = Spacing.Sidebar.rowSpacing
        public static let rowRadius: CGFloat = Spacing.Sidebar.rowRadius
        public static let rowVerticalPadding: CGFloat = Spacing.Sidebar.rowVerticalPadding
        public static let iconBoxSize: CGFloat = Spacing.Sidebar.iconBoxSize
        public static let iconFrameWidth: CGFloat = Spacing.Sidebar.iconFrameWidth
        public static let badgePadding: CGFloat = Spacing.Sidebar.badgePadding
        public static let vaultShadowRadius: CGFloat = Spacing.Sidebar.vaultShadowRadius
        public static let vaultShadowY: CGFloat = Spacing.Sidebar.vaultShadowY
        public static let width: CGFloat = Spacing.Sidebar.width
        public static let backButtonWidth: CGFloat = Spacing.Sidebar.backButtonWidth
    }
}

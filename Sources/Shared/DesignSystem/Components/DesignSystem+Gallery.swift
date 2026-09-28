//
//  DesignSystem+Gallery.swift
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

    // MARK: - 7. 展示模式 (Gallery)
    public enum Gallery {
        public static let itemSize: CGFloat = DesignTokens.Spacing.Gallery.itemSize
        public static let iconSize: CGFloat = DesignTokens.Spacing.Gallery.iconSize
        public static let badgeOffset: CGFloat = DesignTokens.Spacing.Gallery.badgeOffset
        public static let itemRadius: CGFloat = DesignTokens.Spacing.Gallery.itemRadius
        public static let displayIconSize: CGFloat = DesignTokens.Spacing.Gallery.displayIconSize
        public static let splashIconSize: CGFloat = DesignTokens.Spacing.Gallery.splashIconSize
        public static let blurRadius: CGFloat = DesignTokens.Spacing.Gallery.blurRadius
        public static let mainIconSize: CGFloat = DesignTokens.Spacing.Gallery.mainIconSize
        public static let callToActionWidth: CGFloat = DesignTokens.Spacing.Gallery.callToActionWidth
        public static let callToActionHeight: CGFloat = DesignTokens.Spacing.Gallery.callToActionHeight
        public static let containerRadius: CGFloat = DesignTokens.Spacing.Gallery.containerRadius
        public static let containerPadding: CGFloat = DesignTokens.Spacing.Gallery.containerPadding
        public static let showcaseRadius: CGFloat = DesignTokens.Spacing.Gallery.showcaseRadius
        public static let hoverScale: CGFloat = DesignTokens.Spacing.Gallery.hoverScale
        public static let splashLogoBottomPadding: CGFloat = DesignTokens.Spacing.Gallery.splashLogoBottomPadding
        public static let splashButtonBottomPadding: CGFloat = DesignTokens.Spacing.Gallery.splashButtonBottomPadding
        public static let cardMinWidth: CGFloat = DesignTokens.Spacing.Gallery.cardMinWidth
        public static let emptyStateImageSize: CGFloat = DesignTokens.Spacing.Gallery.emptyStateImageSize
        public static let modalMaxWidth: CGFloat = DesignTokens.Spacing.Gallery.modalMaxWidth
    }
}

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

extension DesignSystem {

    // MARK: - 7. 展示模式 (Gallery)
    public enum Gallery {
        public static let itemSize: CGFloat = Spacing.Gallery.itemSize
        public static let iconSize: CGFloat = Spacing.Gallery.iconSize
        public static let badgeOffset: CGFloat = Spacing.Gallery.badgeOffset
        public static let itemRadius: CGFloat = Spacing.Gallery.itemRadius
        public static let displayIconSize: CGFloat = Spacing.Gallery.displayIconSize
        public static let splashIconSize: CGFloat = Spacing.Gallery.splashIconSize
        public static let blurRadius: CGFloat = Spacing.Gallery.blurRadius
        public static let mainIconSize: CGFloat = Spacing.Gallery.mainIconSize
        public static let callToActionWidth: CGFloat = Spacing.Gallery.callToActionWidth
        public static let callToActionHeight: CGFloat = Spacing.Gallery.callToActionHeight
        public static let containerRadius: CGFloat = Spacing.Gallery.containerRadius
        public static let containerPadding: CGFloat = Spacing.Gallery.containerPadding
        public static let showcaseRadius: CGFloat = Spacing.Gallery.showcaseRadius
        public static let hoverScale: CGFloat = Spacing.Gallery.hoverScale
        public static let splashLogoBottomPadding: CGFloat = Spacing.Gallery.splashLogoBottomPadding
        public static let splashButtonBottomPadding: CGFloat = Spacing.Gallery.splashButtonBottomPadding
        public static let cardMinWidth: CGFloat = Spacing.Gallery.cardMinWidth
        public static let emptyStateImageSize: CGFloat = Spacing.Gallery.emptyStateImageSize
        public static let modalMaxWidth: CGFloat = Spacing.Gallery.modalMaxWidth
    }
}

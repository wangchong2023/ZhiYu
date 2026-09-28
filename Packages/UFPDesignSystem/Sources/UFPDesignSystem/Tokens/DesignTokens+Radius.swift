//
//  DesignTokens+Radius.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem]
//  核心职责：原子圆角令牌（Radius）。
//
import SwiftUI
import CoreGraphics

extension DesignTokens {

    // MARK: - 2. 原子圆角 (Radius)
    public enum Radius {
        public static let micro: CGFloat = Spacing.microRadius
        public static let small: CGFloat = Spacing.smallRadius
        public static let medium: CGFloat = Spacing.mediumRadius
        public static let card: CGFloat = Spacing.cardRadius
        public static let standard: CGFloat = Spacing.standardRadius
        public static let large: CGFloat = Spacing.largeRadius
        public static let chip: CGFloat = Spacing.chipRadius
    }
}

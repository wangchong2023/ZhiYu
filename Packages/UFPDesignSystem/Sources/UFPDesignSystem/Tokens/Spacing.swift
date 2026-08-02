//
//  Spacing.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem]
//  核心职责：设计系统 3 级间距 Token 矩阵 (Tier 1 物理 / Tier 2 语义 / Tier 3 组件)。
//

import Foundation
import UFPCore

public enum DesignSystem {
    public enum Spacing {
        // MARK: - Tier 1: 基础物理间距 Token (Base Physical Scale)
        public static let nano: CGFloat = 2.0
        public static let micro: CGFloat = 4.0
        public static let tiny: CGFloat = 6.0
        public static let small: CGFloat = 8.0
        public static let compact: CGFloat = 12.0
        public static let medium: CGFloat = 16.0
        public static let large: CGFloat = 20.0
        public static let extraLarge: CGFloat = 24.0
        public static let huge: CGFloat = 32.0

        // MARK: - Tier 2: 语义化布局间距 Token (Semantic Layout Scale)
        public static let paddingSmall: CGFloat = small
        public static let paddingMedium: CGFloat = medium
        public static let paddingLarge: CGFloat = large

        // MARK: - Tier 3: 视图组件专用间距 Token (Component Token Scale)
        public static let cardPadding: CGFloat = medium
        public static let buttonPaddingHorizontal: CGFloat = medium
        public static let buttonPaddingVertical: CGFloat = compact
    }
}

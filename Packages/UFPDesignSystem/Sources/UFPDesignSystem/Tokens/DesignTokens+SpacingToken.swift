//
//  DesignTokens+SpacingToken.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem]
//  核心职责：强类型间距令牌（SpacingToken）— 映射原子间距物理尺寸。
//
import SwiftUI
import CoreGraphics

extension DesignTokens {

    // MARK: - 强类型间距与圆角令牌

    /// 强类型间距令牌，映射原子间距物理尺寸。
    public enum SpacingToken: Sendable, Hashable {
        /// 最小步进间距 (2px)
        case atomic
        /// 极小间距 (4px)
        case tiny
        /// 小型间距 (8px)
        case small
        /// 中型间距 (12px)
        case medium
        /// 标准页面内边距 (16px)
        case standardPadding
        /// 大型间距 (16px)
        case large
        /// 宽型间距 (20px)
        case wide
        /// 巨型间距 (24px)
        case giant
        /// 极大型间距 (32px)
        case huge

        /// 获取间距的物理 CGFloat 像素值
        public var value: CGFloat {
            switch self {
            case .atomic: return Spacing.atomic
            case .tiny: return Spacing.tiny
            case .small: return Spacing.small
            case .medium: return Spacing.medium
            case .standardPadding: return Spacing.standardPadding
            case .large: return Spacing.large
            case .wide: return Spacing.wide
            case .giant: return Spacing.giant
            case .huge: return Spacing.huge
            }
        }
    }
}

//
//  DesignTokens+RadiusToken.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem]
//  核心职责：强类型圆角令牌（RadiusToken）— 映射原子圆角物理弧度。
//
import SwiftUI
import CoreGraphics

extension DesignTokens {

    /// 强类型圆角令牌，映射原子圆角物理弧度。
    public enum RadiusToken: Sendable, Hashable {
        /// 微型圆角 (4px)
        case micro
        /// 小型圆角 (8px)
        case small
        /// 中型圆角 (10px)
        case medium
        /// 卡片通用圆角 (12px)
        case card
        /// 标准圆角 (12px)
        case standard
        /// 大型圆角 (16px)
        case large
        /// 胶囊型圆角 (20px)
        case chip

        /// 获取圆角物理 CGFloat 弧度值
        public var value: CGFloat {
            switch self {
            case .micro: return Spacing.microRadius
            case .small: return Spacing.smallRadius
            case .medium: return Spacing.mediumRadius
            case .card: return Spacing.cardRadius
            case .standard: return Spacing.standardRadius
            case .large: return Spacing.largeRadius
            case .chip: return Spacing.chipRadius
            }
        }
    }
}

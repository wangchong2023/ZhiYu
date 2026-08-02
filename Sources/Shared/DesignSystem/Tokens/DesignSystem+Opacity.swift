//
//  DesignSystem+Opacity.swift
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

    // MARK: - 6. 视觉令牌 (Visual Tokens)
    public enum Opacity {
        public static let atomic: Double = 0.03
        public static let faint: Double = 0.04
        public static let ghost: Double = 0.05
        public static let light: Double = 0.08
        public static let subtle: Double = 0.12
        public static let glass: Double = 0.15
        public static let medium: Double = 0.2
        public static let shadow: Double = 0.3
        public static let disabled: Double = 0.4
        public static let soft: Double = 0.5
        public static let dim: Double = 0.6
        public static let overlay: Double = 0.7
        public static let prominent: Double = 0.8
        public static let pressed: Double = 0.8
        public static let solid: Double = 1.0
    }
}

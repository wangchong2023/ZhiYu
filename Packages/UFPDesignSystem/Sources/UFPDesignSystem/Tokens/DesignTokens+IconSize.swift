//
//  DesignTokens+IconSize.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem]
//  核心职责：图标尺寸令牌（基础尺寸与宽高常量）。
//
import SwiftUI
import CoreGraphics

extension DesignTokens {
    public enum IconSize {
        public static let atomic: CGFloat = 6
        public static let micro: CGFloat = 16
        public static let small: CGFloat = 20
        public static let standard: CGFloat = 24
        public static let medium: CGFloat = 28
        public static let large: CGFloat = 32
        public static let xlarge: CGFloat = 44
        public static let xxlarge: CGFloat = 46
        public static let huge: CGFloat = 48
    }
}

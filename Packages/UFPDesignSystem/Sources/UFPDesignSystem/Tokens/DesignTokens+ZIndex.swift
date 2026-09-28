//
//  DesignTokens+ZIndex.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem]
//  核心职责：全局层级令牌（ZIndex）。
//
import SwiftUI
import CoreGraphics

extension DesignTokens {

    // MARK: - 13.5 全局层级 (ZIndex)
    public enum ZIndex {
        public static let lockOverlay: Double = 100
        public static let medalPopup: Double = 200
        public static let coachMark: Double = 300
        public static let sidebarOverlay: Double = 1000
    }
}

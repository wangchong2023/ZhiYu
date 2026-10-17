//
//  AdaptiveTypography.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] SPM Package — 物理归位
//  核心职责：自适应排版辅助 —— 根据水平尺寸类选择字号，消除多处重复的三元表达式。
//           沉淀自 ZhiYu App 层 Shared/UIComponents，供包内组件与上层共享。
//

import SwiftUI

/// 根据水平尺寸类选择字号，消除 AppChips / AppFeedback 中重复的 `horizontalSizeClass == .regular ? DesignTokens.Typography.secondaryFont : DesignTokens.Typography.captionFont` 三元表达式。
public enum AdaptiveTypography {
    public static func adaptiveSecondaryFont(horizontalSizeClass: UserInterfaceSizeClass?) -> Font {
        horizontalSizeClass == .regular ? DesignTokens.Typography.secondaryFont : DesignTokens.Typography.captionFont
    }
}
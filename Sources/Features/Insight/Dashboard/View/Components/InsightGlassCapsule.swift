//
//  InsightGlassCapsule.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Insight 模块通用玻璃胶囊 ViewModifier，消除 trendCapsule / 图表快捷入口等重复的
//  padding + background(color.opacity(glassOpacity)) + clipShape(Capsule) 链。
//

import SwiftUI

/// Insight 模块通用玻璃胶囊修饰符
///
/// 统一封装 `padding + background(color.opacity(glassOpacity)) + clipShape(Capsule)` 链，
/// 通过 `color` 参数指定前景与背景基色，消除 Insight 各处重复的胶囊样式代码。
struct InsightGlassCapsuleModifier: ViewModifier {
    var color: Color
    var horizontalPadding: CGFloat = DesignSystem.Chip.horizontalPadding
    var verticalPadding: CGFloat = DesignSystem.Chip.verticalPadding
    var backgroundOpacity: Double = DesignSystem.glassOpacity

    func body(content: Content) -> some View {
        content
            .foregroundStyle(color)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(color.opacity(backgroundOpacity))
            .clipShape(Capsule())
    }
}

extension View {
    /// Insight 玻璃胶囊样式：padding + background(color.opacity) + clipShape(Capsule)
    func insightGlassCapsule(
        color: Color,
        horizontalPadding: CGFloat = DesignSystem.Chip.horizontalPadding,
        verticalPadding: CGFloat = DesignSystem.Chip.verticalPadding,
        backgroundOpacity: Double = DesignSystem.glassOpacity
    ) -> some View {
        modifier(InsightGlassCapsuleModifier(
            color: color,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            backgroundOpacity: backgroundOpacity
        ))
    }
}

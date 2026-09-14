//
//  ContainerCardStyleModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 共享层
//  核心职责：容器卡片样式 ViewModifier，消除 Features 中重复的 background(containerBackground) + clipShape + overlay(stroke containerBorder) 链。
//

import SwiftUI

/// 容器卡片样式修饰符
///
/// 消除 `WeeklyInsightCard.weeklyInsightContainerStyle()` 与 `GraphView` 中重复的
/// `background(DesignSystem.containerBackground).clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius)).overlay(RoundedRectangle.stroke(DesignSystem.containerBorder, lineWidth: DesignSystem.borderWidth))` 模式。
struct ContainerCardStyleModifier: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.cardRadius
    var borderWidth: CGFloat = DesignSystem.borderWidth

    func body(content: Content) -> some View {
        content
            .background(DesignSystem.containerBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DesignSystem.containerBorder, lineWidth: borderWidth)
            )
    }
}

extension View {
    /// 容器卡片样式：background(containerBackground) + clipShape + overlay(stroke containerBorder)
    func containerCardStyle(
        cornerRadius: CGFloat = DesignSystem.cardRadius,
        borderWidth: CGFloat = DesignSystem.borderWidth
    ) -> some View {
        modifier(ContainerCardStyleModifier(cornerRadius: cornerRadius, borderWidth: borderWidth))
    }
}

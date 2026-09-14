//
//  InsightTagChip.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Insight 模块通用标签胶囊样式，消除 EntityDetailBodyView、SourceDetailBodyView、
//  PageDetailHeader、WeeklyInsightCard 中重复的标签/别名胶囊（padding + background + clipShape + overlay(stroke)）布局链。
//

import SwiftUI

/// [L3] 表现层：标签胶囊样式参数
///
/// 共享标签胶囊的样式配置，避免 InsightTagChip 与 InsightTagChipModifier 重复声明相同属性。
struct InsightTagChipStyle {
    var backgroundColor: Color = .appCard
    var backgroundOpacity: Double = DesignSystem.Opacity.subtle
    var borderColor: Color = .appBorder
    var borderWidth: CGFloat = DesignSystem.borderWidth
    var borderOpacity: Double = DesignSystem.Opacity.prominent
    var horizontalPadding: CGFloat = Spacing.Chip.horizontalPadding
    var verticalPadding: CGFloat = Spacing.atomic
}

/// [L3] 表现层：通用标签胶囊
///
/// 统一封装标签/别名的胶囊样式：图标 + 文本 + padding + 背景 + clipShape + overlay(stroke)，
/// 通过 `style` 参数适配不同场景（别名芯片、标签芯片、关键词胶囊）。
struct InsightTagChip: View {
    let text: String
    var icon: String?
    var hashPrefix: Bool = false
    var foregroundColor: Color = .appSecondary
    var font: Font = .caption2.bold()
    var style: InsightTagChipStyle = .init()

    var body: some View {
        HStack(spacing: DesignSystem.atomic) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: SystemFontSize.nano))
            } else if hashPrefix {
                Text(FeatureConstants.Decorator.hash)
                    .font(.system(size: DesignSystem.caption2FontSize, weight: .bold))
            }
            Text(text)
                .font(font)
        }
        .foregroundStyle(foregroundColor)
        .insightTagChipStyle(style)
    }
}

/// [L3] 表现层：标签胶囊样式修饰符
///
/// 为已有内容追加统一的胶囊容器样式（padding + background + clipShape + overlay(stroke)），
/// 适用于需要自定义内部布局但仍需统一外观的场景。
struct InsightTagChipModifier: ViewModifier {
    var style: InsightTagChipStyle = .init()

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background(style.backgroundColor.opacity(style.backgroundOpacity))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(style.borderColor.opacity(style.borderOpacity), lineWidth: style.borderWidth)
            )
    }
}

extension View {
    /// 应用标签胶囊容器样式（padding + background + clipShape + overlay(stroke)）
    func insightTagChipStyle(_ style: InsightTagChipStyle = .init()) -> some View {
        modifier(InsightTagChipModifier(style: style))
    }
}

/// [L3] 表现层：标签计数徽章
///
/// 统一封装标签词频数字的胶囊样式：monospaced 字体 + padding + 背景 + clipShape(Capsule)，
/// 消除 CircularTagBubbleView 与 TagCapsuleView 中重复的计数徽章布局。
struct InsightTagCountBadge: View {
    let count: Int
    let fontSize: CGFloat
    let isSelected: Bool
    let selectedColor: Color
    let unselectedColor: Color

    var body: some View {
        Text("\(count)")
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .padding(.horizontal, SystemSpacing.tiny)
            .padding(.vertical, SystemSpacing.divider)
            .background(isSelected ? selectedColor : unselectedColor)
            .clipShape(Capsule())
    }
}

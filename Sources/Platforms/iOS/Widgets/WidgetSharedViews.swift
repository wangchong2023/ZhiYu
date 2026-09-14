//
//  WidgetSharedViews.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Platforms] Widget Extension
//  核心职责：Widget Extension 共享 SwiftUI 子视图组件，消除多个 Widget 文件中
//           重复的引文卡片、统计条目、操作按钮等视图构造模式。
//

import SwiftUI

// MARK: - 引文卡片行

/// Widget 引文卡片行：图标 + 文本 + 微妙背景，用于 DailyInsightWidget largeView
/// 与 KnowledgeStatsWidget largeView 中重复的引文展示模式。
struct WidgetInsightQuoteRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: WidgetVisualConstants.spacingStandard) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .padding(WidgetVisualConstants.spacingStandard)
        .background(Color.white.opacity(WidgetVisualConstants.opacitySubtle))
        .clipShape(RoundedRectangle(cornerRadius: WidgetVisualConstants.cardCornerRadius))
    }
}

// MARK: - 统计条目（小尺寸）

/// Widget 小尺寸统计条目：圆点 + 标签 + 数值，用于 KnowledgeStatsWidget smallView。
struct WidgetStatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: WidgetVisualConstants.legendDotSize, height: WidgetVisualConstants.legendDotSize)
            Text("\(label):")
                .font(.system(size: WidgetVisualConstants.microFontSize))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: WidgetVisualConstants.microFontSize, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - 主统计条目（中尺寸）

/// Widget 中尺寸主统计条目：大号数值 + 小号标签，用于 KnowledgeStatsWidget medium/largeView。
struct WidgetMainStatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: WidgetVisualConstants.microFontSize, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 操作按钮（Deep Link）

/// Widget Deep Link 操作按钮：图标 + 标签 + 描边背景，用于 KnowledgeStatsWidget mediumView。
struct WidgetActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let url: String

    var body: some View {
        Link(destination: URL(string: url) ?? URL(string: "about:blank")!) {
            HStack(spacing: WidgetVisualConstants.spacingCompact) {
                Image(systemName: icon)
                    .font(.system(size: WidgetVisualConstants.smallFontSize))
                Text(label)
                    .font(.system(size: WidgetVisualConstants.smallFontSize, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, WidgetVisualConstants.verticalPadding)
            .background(Color.white.opacity(WidgetVisualConstants.opacitySubtle))
            .overlay(
                RoundedRectangle(cornerRadius: WidgetVisualConstants.widgetCornerRadius)
                    .stroke(color.opacity(WidgetVisualConstants.opacityGlow), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WidgetVisualConstants.widgetCornerRadius))
        }
    }
}

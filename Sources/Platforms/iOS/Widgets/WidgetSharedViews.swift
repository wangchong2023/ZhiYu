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
import WidgetKit

// MARK: - Deep Link URL 辅助

/// Widget Deep Link URL 解析辅助，消除多个 Widget 中重复的
/// `URL(string: url) ?? URL(string: "about:blank")!` 模式。
enum WidgetDeepLinkURL {
    /// 将字符串 URL 安全转换为 URL，无效时回退到 about:blank 占位。
    static func resolve(_ urlString: String) -> URL {
        URL(string: urlString) ?? URL(string: "about:blank")!
    }
}

// MARK: - Widget 容器背景

/// Widget 统一容器背景修饰器，消除多个 Widget EntryView 中重复的
/// `ZStack { gradientBackground; switch family }; .containerBackground { Color.clear }` 模式。
struct WidgetContainerBackground<Content: View>: View {
    @Environment(\.widgetFamily) private var family
    @ViewBuilder let content: (WidgetFamily) -> Content

    var body: some View {
        ZStack {
            WidgetVisualConstants.gradientBackground
            content(family)
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

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

/// Widget 知识库统计对（vaultName + links），消除 mediumView 与 largeView 中重复的
/// `WidgetMainStatItem(vaultName, pageCount, purple) + WidgetMainStatItem(links, linkCount, blue)` 模式。
struct WidgetVaultStatPair: View {
    let pageCount: Int
    let linkCount: Int

    var body: some View {
        WidgetMainStatItem(label: WidgetL10n.vaultName, value: "\(pageCount)", color: WidgetSharedConstants.Color.purple)
        WidgetMainStatItem(label: WidgetL10n.links, value: "\(linkCount)", color: WidgetSharedConstants.Color.blue)
    }
}

// MARK: - 操作按钮（Deep Link）

/// Widget Deep Link 按钮内部标签：`HStack { Image + Text }`，
/// 消除 WidgetActionButton 与 WidgetLargeAIButton 中重复的 `HStack(spacing:) { Image + Text }` 构造。
struct WidgetLinkLabel: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: WidgetVisualConstants.spacingCompact) {
            Image(systemName: icon)
            Text(label)
        }
    }
}

/// Widget Deep Link 操作按钮：图标 + 标签 + 描边背景，用于 KnowledgeStatsWidget mediumView。
struct WidgetActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let url: String

    var body: some View {
        Link(destination: WidgetDeepLinkURL.resolve(url)) {
            WidgetLinkLabel(icon: icon, label: label)
                .font(.system(size: WidgetVisualConstants.smallFontSize, weight: .bold))
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

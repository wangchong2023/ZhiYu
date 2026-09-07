//
//  WidgetAndWatchViews.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：SwiftUI 视图，负责 WidgetAndWatchs 界面的布局与渲染。
//
import SwiftUI
import UFPCore
import WidgetKit
import Dependencies

// MARK: - 1. 每日 AI 洞察/闪念小组件视图 (Daily AI Insight Widget)
public struct DailyInsightWidgetView: View {
    public let title: String
    public let content: String

    public init(title: String = L10n.Widget.llmWikiChunking, content: String = L10n.Widget.llmWikiDescription) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            HStack(spacing: DesignSystem.tiny) {
                Image(systemName: DesignSystem.Icons.sparkle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appAccent)
                Text(L10n.Widget.dailyInsight)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appText)
                Spacer()
                Text(L10n.Widget.zhiyuAI)
                    .font(.caption2)
                    .foregroundStyle(Color.appSecondary)
            }

            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)
                    .lineLimit(1)
                
                Text(content)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondary)
                    .lineLimit(3)
            }
            .padding(DesignSystem.small)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                    .fill(Color.appCard)
            )
        }
        .padding(DesignSystem.small)
    }
}

// MARK: - 2. 知识库分布与热度小组件视图 (Knowledge Distribution Widget)
public struct KnowledgeDistributionWidgetView: View {
    public let pageCount: Int
    public let distribution: [String: Double]

    public init(pageCount: Int = PlatformConstants.WidgetWatch.defaultPageCount, distribution: [String: Double] = PlatformConstants.WidgetWatch.defaultDistribution) {
        self.pageCount = pageCount
        self.distribution = distribution
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            HStack {
                Label(L10n.Widget.knowledgeDistribution, systemImage: DesignSystem.Icons.mindmap)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appAccent)
                Spacer()
                Text(L10n.Widget.pages(pageCount))
                    .font(.caption2)
                    .foregroundStyle(Color.appSecondary)
            }

            HStack(spacing: DesignSystem.tiny) {
                ForEach(Array(distribution.keys.sorted()), id: \.self) { key in
                    VStack(spacing: DesignSystem.atomic) {
                        Text(key)
                            .font(.caption2)
                            .foregroundStyle(Color.appSecondary)
                        
                        RoundedRectangle(cornerRadius: DesignSystem.atomic)
                            .fill(Color.appAccent.opacity(distribution[key] ?? PlatformConstants.WidgetWatch.distributionFallbackOpacity))
                            .frame(height: DesignSystem.tiny)
                    }
                }
            }
        }
        .padding(DesignSystem.small)
    }
}

// MARK: - 3. 极速捕获与 AI 助手快捷入口小组件 (Quick Capture Widget)
public struct QuickCaptureWidgetView: View {
    public init() {}

    public var body: some View {
        HStack(spacing: DesignSystem.medium) {
            shortcutItem(icon: DesignSystem.Icons.voiceNote, label: L10n.Widget.voice)
            shortcutItem(icon: DesignSystem.Icons.scan, label: L10n.Widget.ocr)
            shortcutItem(icon: DesignSystem.Icons.search, label: L10n.Widget.search)
            shortcutItem(icon: DesignSystem.Icons.sparkle, label: L10n.Widget.qa)
        }
        .padding(DesignSystem.small)
    }

    private func shortcutItem(icon: String, label: String) -> some View {
        VStack(spacing: DesignSystem.tiny) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(DesignSystem.Opacity.soft))
                    .frame(width: Spacing.Action.backButtonWidth, height: Spacing.Action.backButtonWidth)
                
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appAccent)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.appText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 4. Apple Watch 每日洞察与闪念轮播视图 (Watch Daily Insight View)
public struct WatchDailyInsightView: View {
    public let insights: [String]

    public init(insights: [String] = [
        L10n.Widget.insightQuote1,
        L10n.Widget.insightQuote2,
        L10n.Widget.insightQuote3
    ]) {
        self.insights = insights
    }

    public var body: some View {
        TabView {
            ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                VStack(spacing: DesignSystem.small) {
                    Image(systemName: DesignSystem.Icons.sparkle)
                        .font(.title3)
                        .foregroundStyle(Color.appAccent)
                    
                    Text(insight)
                        .font(.caption)
                        .foregroundStyle(Color.appText)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                }
                .padding(DesignSystem.small)
            }
        }
        #if os(watchOS)
        .tabViewStyle(.page)
        #endif
    }
}

#Preview(L10n.Widget.widgetsPreview) {
    VStack(spacing: SystemSpacing.content) {
        DailyInsightWidgetView()
        KnowledgeDistributionWidgetView()
        QuickCaptureWidgetView()
    }
}

//
//  DailyInsightWidget.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 桌面与锁屏【每日 AI 洞察/闪念卡片】Widget 渲染与 Timeline 管理。
//

import SwiftUI
@preconcurrency import WidgetKit

// MARK: - Timeline Entry
struct DailyInsightEntry: TimelineEntry {
    let date: Date
    let insight: WidgetDailyInsight
}

// MARK: - Provider
struct DailyInsightProvider: TimelineProvider {
    typealias Entry = DailyInsightEntry

    func placeholder(in context: Context) -> DailyInsightEntry {
        DailyInsightEntry(
            date: Date(),
            insight: WidgetDailyInsight(
                title: WidgetL10n.llmWikiChunking,
                content: WidgetL10n.llmWikiDescription,
                flashThoughtSummary: WidgetL10n.flashThoughtSub
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (DailyInsightEntry) -> Void) {
        Task {
            let insight = await WidgetRepository.fetchDailyInsight()
            await MainActor.run {
                completion(DailyInsightEntry(date: Date(), insight: insight))
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<DailyInsightEntry>) -> Void) {
        Task.detached {
            let insight = await WidgetRepository.fetchDailyInsight()
            let entry = DailyInsightEntry(date: Date(), insight: insight)
            WidgetTimelineBuilder.buildSingleTimeline(entry: entry, completion: completion)
        }
    }
}

// MARK: - Widget View
struct DailyInsightWidgetEntryView: View {
    var entry: DailyInsightProvider.Entry

    var body: some View {
        WidgetContainerBackground { family in
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView
            case .accessoryRectangular:
                accessoryView
            default:
                mediumView
            }
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: WidgetVisualConstants.spacingStandard) {
            HStack(spacing: WidgetVisualConstants.spacingCompact) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(WidgetSharedConstants.Color.purple)
                Text(WidgetL10n.dailyInsight)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.insight.title)
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(entry.insight.flashThoughtSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(WidgetVisualConstants.spacingWide)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Label(WidgetL10n.dailyInsight, systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetSharedConstants.Color.purple)

                Spacer()

                Text(entry.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(entry.insight.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(entry.insight.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Spacer()

            HStack {
                Image(systemName: "quote.bubble.fill")
                    .font(.caption2)
                    .foregroundStyle(WidgetSharedConstants.Color.blue)
                Text(entry.insight.flashThoughtSummary)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(WidgetVisualConstants.opacitySoft))
                    .lineLimit(1)
            }
        }
        .padding(14)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: WidgetVisualConstants.spacingLarge) {
            mediumView

            Divider().background(Color.white.opacity(WidgetVisualConstants.opacityLight))

            VStack(alignment: .leading, spacing: WidgetVisualConstants.spacingStandard) {
                Text(WidgetL10n.recentUpdates)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetSharedConstants.Color.purple)

                WidgetInsightQuoteRow(
                    icon: "brain.head.profile",
                    color: WidgetSharedConstants.Color.blue,
                    text: WidgetL10n.insightQuote1
                )
                WidgetInsightQuoteRow(
                    icon: "bolt.horizontal.fill",
                    color: WidgetSharedConstants.Color.orange,
                    text: WidgetL10n.insightQuote2
                )
            }
        }
        .padding(14)
    }

    private var accessoryView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(WidgetL10n.dailyInsight, systemImage: "sparkles")
                .font(.caption2.weight(.bold))
            Text(entry.insight.title)
                .font(.caption2)
                .lineLimit(2)
        }
    }
}

// MARK: - Widget Definition
struct DailyInsightWidget: Widget {
    let kind: String = "DailyInsightWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyInsightProvider()) { entry in
            DailyInsightWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetL10n.dailyInsight)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

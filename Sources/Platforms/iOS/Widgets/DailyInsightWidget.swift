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

private enum WidgetMetrics {
    static let opacitySoft: Double = 0.9
    static let opacityLight: Double = 0.1
    static let opacitySubtle: Double = 0.05
    static let cardCornerRadius: CGFloat = 8
    static let darkBgTop = Color(red: 0.1, green: 0.11, blue: 0.18)
    static let darkBgBottom = Color(red: 0.06, green: 0.07, blue: 0.12)
    static let refreshIntervalSeconds: TimeInterval = 1800
}

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
            await MainActor.run {
                let nextUpdate = Date().addingTimeInterval(WidgetMetrics.refreshIntervalSeconds)
                let timeline = Timeline(entries: [DailyInsightEntry(date: Date(), insight: insight)], policy: .after(nextUpdate))
                completion(timeline)
            }
        }
    }
}

// MARK: - Widget View
struct DailyInsightWidgetEntryView: View {
    var entry: DailyInsightProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WidgetMetrics.darkBgTop, WidgetMetrics.darkBgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

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
        .containerBackground(for: .widget) { Color.clear }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.purple)
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
        .padding(12)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Label(WidgetL10n.dailyInsight, systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.purple)

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
                    .foregroundStyle(.blue)
                Text(entry.insight.flashThoughtSummary)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(WidgetMetrics.opacitySoft))
                    .lineLimit(1)
            }
        }
        .padding(14)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            mediumView

            Divider().background(Color.white.opacity(WidgetMetrics.opacityLight))

            VStack(alignment: .leading, spacing: 6) {
                Text(WidgetL10n.recentUpdates)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.purple)

                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.blue)
                    Text(WidgetL10n.insightQuote1)
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
                .padding(8)
                .background(Color.white.opacity(WidgetMetrics.opacitySubtle))
                .clipShape(RoundedRectangle(cornerRadius: WidgetMetrics.cardCornerRadius))

                HStack(spacing: 8) {
                    Image(systemName: "bolt.horizontal.fill")
                        .foregroundStyle(.orange)
                    Text(WidgetL10n.insightQuote2)
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
                .padding(8)
                .background(Color.white.opacity(WidgetMetrics.opacitySubtle))
                .clipShape(RoundedRectangle(cornerRadius: WidgetMetrics.cardCornerRadius))
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

//
//  KnowledgeDistributionWidget.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 桌面【知识库热度与分布卡片】Widget 渲染与 Timeline 管理。
//

import SwiftUI
@preconcurrency import WidgetKit

private enum WidgetMetrics {
    static let darkBgTop = Color(red: 0.1, green: 0.11, blue: 0.18)
    static let darkBgBottom = Color(red: 0.06, green: 0.07, blue: 0.12)
    static let opacityLight: Double = 0.1
    static let opacitySubtle: Double = 0.4
    static let minSegmentWidth: CGFloat = 8
    static let barHeight: CGFloat = 10
    static let legendDotSize: CGFloat = 6
    static let heatSquareHeight: CGFloat = 30
    static let cornerRadius: CGFloat = 3
    static let heatCornerRadius: CGFloat = 4
    static let refreshIntervalSeconds: TimeInterval = 1800
}

// MARK: - Timeline Entry
struct KnowledgeDistributionEntry: TimelineEntry {
    let date: Date
    let distribution: WidgetDistributionStats
}

// MARK: - Provider
struct KnowledgeDistributionProvider: TimelineProvider {
    typealias Entry = KnowledgeDistributionEntry

    func placeholder(in context: Context) -> KnowledgeDistributionEntry {
        KnowledgeDistributionEntry(
            date: Date(),
            distribution: WidgetDistributionStats(
                sourceRatio: 0.4,
                conceptRatio: 0.3,
                entityRatio: 0.2,
                mapRatio: 0.1,
                weeklyGrowth: 18
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (KnowledgeDistributionEntry) -> Void) {
        Task {
            let dist = await WidgetRepository.fetchDistribution()
            await MainActor.run {
                completion(KnowledgeDistributionEntry(date: Date(), distribution: dist))
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<KnowledgeDistributionEntry>) -> Void) {
        Task.detached {
            let dist = await WidgetRepository.fetchDistribution()
            await MainActor.run {
                let nextUpdate = Date().addingTimeInterval(WidgetMetrics.refreshIntervalSeconds)
                let timeline = Timeline(entries: [KnowledgeDistributionEntry(date: Date(), distribution: dist)], policy: .after(nextUpdate))
                completion(timeline)
            }
        }
    }
}

// MARK: - Widget View
struct KnowledgeDistributionWidgetEntryView: View {
    var entry: KnowledgeDistributionProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WidgetMetrics.darkBgTop, WidgetMetrics.darkBgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            switch family {
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView
            default:
                mediumView
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Label(WidgetL10n.knowledgeDistribution, systemImage: "chart.pie.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetSharedConstants.Color.purple)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(WidgetSharedConstants.Color.orange)
                    Text("+\(entry.distribution.weeklyGrowth)% / W")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(WidgetSharedConstants.Color.orange)
                }
            }

            // 分类分布比例条形图
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: WidgetMetrics.cornerRadius)
                        .fill(Color.purple)
                        .frame(width: max(WidgetMetrics.minSegmentWidth, proxy.size.width * CGFloat(entry.distribution.sourceRatio)))
                    RoundedRectangle(cornerRadius: WidgetMetrics.cornerRadius)
                        .fill(Color.blue)
                        .frame(width: max(WidgetMetrics.minSegmentWidth, proxy.size.width * CGFloat(entry.distribution.conceptRatio)))
                    RoundedRectangle(cornerRadius: WidgetMetrics.cornerRadius)
                        .fill(Color.teal)
                        .frame(width: max(WidgetMetrics.minSegmentWidth, proxy.size.width * CGFloat(entry.distribution.entityRatio)))
                    RoundedRectangle(cornerRadius: WidgetMetrics.cornerRadius)
                        .fill(Color.orange)
                        .frame(width: max(WidgetMetrics.minSegmentWidth, proxy.size.width * CGFloat(entry.distribution.mapRatio)))
                }
            }
            .frame(height: WidgetMetrics.barHeight)

            // 图例网格
            HStack(spacing: 12) {
                legendItem(label: WidgetL10n.source, ratio: entry.distribution.sourceRatio, color: WidgetSharedConstants.Color.purple)
                legendItem(label: WidgetL10n.concept, ratio: entry.distribution.conceptRatio, color: WidgetSharedConstants.Color.blue)
                legendItem(label: WidgetL10n.entity, ratio: entry.distribution.entityRatio, color: WidgetSharedConstants.Color.teal)
                legendItem(label: WidgetL10n.map, ratio: entry.distribution.mapRatio, color: WidgetSharedConstants.Color.orange)
            }
            .padding(.top, 4)
        }
        .padding(14)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            mediumView

            Divider().background(Color.white.opacity(WidgetMetrics.opacityLight))

            Text(WidgetL10n.weeklyHeatmap)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            // 周度周天活跃方格图
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: WidgetMetrics.heatCornerRadius)
                            .fill(dayIndex % 2 == 0 ? Color.purple : Color.purple.opacity(WidgetMetrics.opacitySubtle))
                            .frame(height: WidgetMetrics.heatSquareHeight)
                        Text(["M", "T", "W", "T", "F", "S", "S"][dayIndex])
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
    }

    private func legendItem(label: String, ratio: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: WidgetMetrics.legendDotSize, height: WidgetMetrics.legendDotSize)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .bold)) // Dynamic Type
                    .foregroundStyle(.secondary)
                Text("\(Int(ratio * 100))%")
                    .font(.system(size: 10, weight: .bold)) // Dynamic Type
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Widget Definition
struct KnowledgeDistributionWidget: Widget {
    let kind: String = "KnowledgeDistributionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KnowledgeDistributionProvider()) { entry in
            KnowledgeDistributionWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetL10n.knowledgeDistribution)
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

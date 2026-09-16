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
            let entry = KnowledgeDistributionEntry(date: Date(), distribution: dist)
            WidgetTimelineBuilder.buildSingleTimeline(entry: entry, completion: completion)
        }
    }
}

// MARK: - Widget View
struct KnowledgeDistributionWidgetEntryView: View {
    var entry: KnowledgeDistributionProvider.Entry

    var body: some View {
        WidgetContainerBackground { family in
            switch family {
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView
            default:
                mediumView
            }
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Label(WidgetL10n.knowledgeDistribution, systemImage: "chart.pie.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetSharedConstants.Color.purple)

                Spacer()

                HStack(spacing: WidgetVisualConstants.spacingCompact) {
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
                    WidgetDistributionSegment(
                        color: WidgetSharedConstants.Color.purple,
                        ratio: entry.distribution.sourceRatio,
                        proxyWidth: proxy.size.width
                    )
                    WidgetDistributionSegment(
                        color: WidgetSharedConstants.Color.blue,
                        ratio: entry.distribution.conceptRatio,
                        proxyWidth: proxy.size.width
                    )
                    WidgetDistributionSegment(
                        color: WidgetSharedConstants.Color.teal,
                        ratio: entry.distribution.entityRatio,
                        proxyWidth: proxy.size.width
                    )
                    WidgetDistributionSegment(
                        color: WidgetSharedConstants.Color.orange,
                        ratio: entry.distribution.mapRatio,
                        proxyWidth: proxy.size.width
                    )
                }
            }
            .frame(height: WidgetVisualConstants.barHeight)

            // 图例网格
            HStack(spacing: WidgetVisualConstants.spacingLarge) {
                legendItem(label: WidgetL10n.source, ratio: entry.distribution.sourceRatio, color: WidgetSharedConstants.Color.purple)
                legendItem(label: WidgetL10n.concept, ratio: entry.distribution.conceptRatio, color: WidgetSharedConstants.Color.blue)
                legendItem(label: WidgetL10n.entity, ratio: entry.distribution.entityRatio, color: WidgetSharedConstants.Color.teal)
                legendItem(label: WidgetL10n.map, ratio: entry.distribution.mapRatio, color: WidgetSharedConstants.Color.orange)
            }
            .padding(.top, WidgetVisualConstants.spacingCompact)
        }
        .padding(14)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            mediumView

            Divider().background(Color.white.opacity(WidgetVisualConstants.opacityLight))

            Text(WidgetL10n.weeklyHeatmap)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            // 周度周天活跃方格图
            HStack(spacing: WidgetVisualConstants.spacingStandard) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    VStack(spacing: WidgetVisualConstants.spacingCompact) {
                        RoundedRectangle(cornerRadius: WidgetVisualConstants.heatCornerRadius)
                            .fill(dayIndex % 2 == 0 ? Color.purple : Color.purple.opacity(WidgetVisualConstants.opacityGlow))
                            .frame(height: WidgetVisualConstants.heatSquareHeight)
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
        HStack(spacing: WidgetVisualConstants.spacingCompact) {
            Circle()
                .fill(color)
                .frame(width: WidgetVisualConstants.legendDotSize, height: WidgetVisualConstants.legendDotSize)
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

// MARK: - 分布条形图分段

/// 知识分布条形图的单个分段，消除 KnowledgeDistributionWidget 中 4 次重复的
/// `RoundedRectangle + fill + frame(max(minSegmentWidth, proxyWidth * ratio))` 模式。
struct WidgetDistributionSegment: View {
    let color: Color
    let ratio: Double
    let proxyWidth: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: WidgetVisualConstants.cornerRadius)
            .fill(color)
            .frame(width: max(WidgetVisualConstants.minSegmentWidth, proxyWidth * CGFloat(ratio)))
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

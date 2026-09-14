//
//  KnowledgeStatsWidget.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台实现：后台任务、Widget、文件归档、Spotlight 索引。
//
import SwiftUI
@preconcurrency import WidgetKit

// MARK: - Widget 设计常量（KnowledgeStats 专属，未纳入共享集）

/// KnowledgeStatsWidget 专属常量（未在其他 Widget 中复用，保留私有定义）
private enum KnowledgeStatsMetrics {
    // MARK: - Padding
    static let cardPadding: CGFloat = 16
    static let contentPadding: CGFloat = 12
    static let footerPadding: CGFloat = 18

    // MARK: - Size
    static let iconSize: CGFloat = 20
    static let progressBarWidth: CGFloat = 80

    // MARK: - Spacing
    static let spacingTiny: CGFloat = 2
    static let spacingSmall: CGFloat = 3
    static let spacingRegular: CGFloat = 10
    static let spacingXLarge: CGFloat = 24

    // MARK: - Font Sizes
    static let captionSize: CGFloat = 8

    // MARK: - Opacity
    static let opacityHalf: Double = 0.5

    // MARK: - Refresh
    /// 小组件刷新间隔（分钟）
    static let widgetRefreshIntervalMinutes: Double = 30.0
    static let gradientStartRadius: CGFloat = 10
    static let gradientEndRadius: CGFloat = 180
}

// MARK: - Timeline Entry
/// 桌面静态小组件的时间线实体
struct KnowledgeStatsEntry: TimelineEntry {
    let date: Date
    let vaultName: String
    let pageCount: Int
    let linkCount: Int
    let tagCount: Int
    let lastUpdatedPages: [WidgetRecentPage]
}

// MARK: - Timeline Provider
/// 桌面静态小组件的时间线提供商
struct KnowledgeStatsProvider: TimelineProvider {
    typealias Entry = KnowledgeStatsEntry

    /// 占位符：Widget 初次渲染或快速预览时使用
    /// - Parameter context: context
    /// - Returns: 空数据的 TimelineEntry
    func placeholder(in context: Context) -> KnowledgeStatsEntry {
        KnowledgeStatsEntry(
            date: Date(),
            vaultName: WidgetL10n.title,
            pageCount: 0,
            linkCount: 0,
            tagCount: 0,
            lastUpdatedPages: []
        )
    }

    /// 快照：Widget 添加到桌面或预览时调用
    /// - Parameter completion: completion
    func getSnapshot(in context: Context, completion: @escaping @Sendable (KnowledgeStatsEntry) -> Void) {
        Task {
            let entry = await buildEntry(for: Date())
            await MainActor.run { completion(entry) }
        }
    }

    /// 时间线：Widget 按刷新策略定期更新
    /// - Parameter completion: completion
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<KnowledgeStatsEntry>) -> Void) {
        Task.detached {
            let entry = await buildEntry(for: Date())
            await MainActor.run {
                let nextUpdate = Date().addingTimeInterval(KnowledgeStatsMetrics.widgetRefreshIntervalMinutes * 60)
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            }
        }
    }

    /// 异步构建小组件数据实体
    /// 从 App Group 共享数据库读取真实统计数据和最近更新页面列表
    /// - Parameter date: 当前时间
    /// - Returns: 包含真实数据的 KnowledgeStatsEntry
    private func buildEntry(for date: Date) async -> KnowledgeStatsEntry {
        let stats = await WidgetRepository.fetchStats()
        let recentPages = await WidgetRepository.fetchRecentPages(limit: 3)
        return KnowledgeStatsEntry(
            date: date,
            vaultName: WidgetL10n.title,
            pageCount: stats.pageCount,
            linkCount: stats.linkCount,
            tagCount: stats.tagCount,
            lastUpdatedPages: recentPages
        )
    }
}

// MARK: - Widget View
/// 桌面静态小组件的主体渲染视图
struct KnowledgeStatsWidgetEntryView: View {
    var entry: KnowledgeStatsProvider.Entry

    var body: some View {
        WidgetContainerBackground { family in
            // 霓虹光环点缀 (Platinum UI Design)
            RadialGradient(
                colors: [Color.purple.opacity(WidgetVisualConstants.opacityMedium), Color.clear],
                center: .topTrailing,
                startRadius: KnowledgeStatsMetrics.gradientStartRadius,
                endRadius: KnowledgeStatsMetrics.gradientEndRadius
            )

            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView
            case .systemExtraLarge:
                // iPad 超大尺寸：复用 Large 布局
                largeView
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                // 锁屏/StandBy 辅助小组件：降级展示紧凑摘要
                smallView
            @unknown default:
                smallView
            }
        }
    }

    // MARK: - Small 尺寸布局
    private var smallView: some View {
        VStack(alignment: .leading, spacing: KnowledgeStatsMetrics.spacingRegular) {
            vaultHeader(iconFont: .footnote, titleFont: .caption2.bold())

            Spacer()

            VStack(alignment: .leading, spacing: KnowledgeStatsMetrics.spacingTiny) {
                Text("\(entry.pageCount)")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.black)
                    .foregroundStyle(.white)

                Text(WidgetL10n.vaultName)
                    .font(.system(size: WidgetVisualConstants.smallFontSize, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: WidgetVisualConstants.spacingWide) {
                WidgetStatItem(label: WidgetL10n.links, value: "\(entry.linkCount)", color: WidgetSharedConstants.Color.blue)
                WidgetStatItem(label: WidgetL10n.tags, value: "\(entry.tagCount)", color: WidgetSharedConstants.Color.orange)
            }
        }
        .padding(KnowledgeStatsMetrics.contentPadding)
    }

    // MARK: - Medium 尺寸布局
    private var mediumView: some View {
        HStack(spacing: WidgetVisualConstants.spacingLarge) {
            // 左侧：数据面板
            VStack(alignment: .leading, spacing: WidgetVisualConstants.spacingWide) {
                vaultHeader(iconFont: .caption, titleFont: .caption.bold())

                HStack(spacing: WidgetVisualConstants.spacingLarge) {
                    WidgetMainStatItem(label: WidgetL10n.vaultName, value: "\(entry.pageCount)", color: WidgetSharedConstants.Color.purple)
                    WidgetMainStatItem(label: WidgetL10n.links, value: "\(entry.linkCount)", color: WidgetSharedConstants.Color.blue)
                }

                HStack(spacing: WidgetVisualConstants.spacingLarge) {
                    WidgetMainStatItem(label: WidgetL10n.tags, value: "\(entry.tagCount)", color: WidgetSharedConstants.Color.orange)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(Color.white.opacity(WidgetVisualConstants.opacityLight))
                .padding(.vertical, WidgetVisualConstants.spacingStandard)

            // 右侧：Deep Link 快捷操作区
            VStack(spacing: WidgetVisualConstants.spacingStandard) {
                WidgetActionButton(label: WidgetL10n.create, icon: "plus.circle.fill", color: WidgetSharedConstants.Color.purple, url: WidgetSharedConstants.DeepLink.create)
                WidgetActionButton(label: WidgetL10n.aiChat, icon: "sparkles", color: WidgetSharedConstants.Color.blue, url: WidgetSharedConstants.DeepLink.chat)
                WidgetActionButton(label: WidgetL10n.search, icon: "magnifyingglass", color: WidgetSharedConstants.Color.orange, url: WidgetSharedConstants.DeepLink.search)
            }
            .frame(width: KnowledgeStatsMetrics.progressBarWidth)
        }
        .padding(KnowledgeStatsMetrics.cardPadding)
    }

    // MARK: - Large 尺寸布局
    private var largeView: some View {
        VStack(alignment: .leading, spacing: WidgetVisualConstants.spacingLarge) {
            // 顶半部复用 Medium 的统计信息
            HStack(spacing: WidgetVisualConstants.spacingLarge) {
                VStack(alignment: .leading, spacing: WidgetVisualConstants.spacingStandard) {
                    vaultHeader(iconFont: .caption, titleFont: .caption.bold())

                    HStack(spacing: KnowledgeStatsMetrics.spacingXLarge) {
                        WidgetMainStatItem(label: WidgetL10n.vaultName, value: "\(entry.pageCount)", color: WidgetSharedConstants.Color.purple)
                        WidgetMainStatItem(label: WidgetL10n.links, value: "\(entry.linkCount)", color: WidgetSharedConstants.Color.blue)
                        WidgetMainStatItem(label: WidgetL10n.tags, value: "\(entry.tagCount)", color: WidgetSharedConstants.Color.orange)
                    }
                }

                Spacer()

                // 快捷大按钮
                WidgetLargeAIButton(label: WidgetL10n.ai, url: WidgetSharedConstants.DeepLink.chat)
            }

            Divider().background(Color.white.opacity(WidgetVisualConstants.opacityLight))

            // 下半部：最近更新的知识页卡片列表
            VStack(alignment: .leading, spacing: KnowledgeStatsMetrics.spacingRegular) {
                Text(WidgetL10n.recentUpdates)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.bottom, KnowledgeStatsMetrics.spacingTiny)

                ForEach(entry.lastUpdatedPages) { page in
                    WidgetRecentPageRow(page: page)
                }
            }
        }
        .padding(KnowledgeStatsMetrics.footerPadding)
    }

    // MARK: - 共享子视图

    /// 知识库标题头部：图标 + 仓库名，消除 smallView/mediumView/largeView 间重复的
    /// `HStack { Image("books.vertical.fill"); Text(vaultName) }` 模式。
    @ViewBuilder
    private func vaultHeader(iconFont: Font, titleFont: Font) -> some View {
        HStack(spacing: WidgetVisualConstants.spacingCompact) {
            Image(systemName: "books.vertical.fill")
                .font(iconFont)
                .foregroundStyle(WidgetSharedConstants.Color.purple)
            Text(entry.vaultName)
                .font(titleFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - 大尺寸 AI 按钮

/// KnowledgeStatsWidget largeView 中的大号 AI 胶囊按钮，消除重复的
/// `Link + HStack + Capsule` 构造模式。
struct WidgetLargeAIButton: View {
    let label: String
    let url: String

    var body: some View {
        Link(destination: WidgetDeepLinkURL.resolve(url)) {
            HStack(spacing: WidgetVisualConstants.spacingCompact) {
                Image(systemName: "sparkles")
                Text(label)
            }
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, WidgetVisualConstants.edgePadding)
            .padding(.vertical, WidgetVisualConstants.verticalPadding)
            .background(Capsule().fill(Color.purple))
        }
    }
}

// MARK: - 最近更新页行

/// KnowledgeStatsWidget largeView 中的最近更新页卡片行，消除重复的
/// `HStack + Image + Text + chevron` 构造模式。
struct WidgetRecentPageRow: View {
    let page: WidgetRecentPage

    var body: some View {
        HStack(spacing: WidgetVisualConstants.spacingStandard) {
            Image(systemName: page.typeName == "concept" ? "lightbulb.fill" : "person.text.rectangle.fill")
                .font(.system(size: WidgetVisualConstants.captionFontSize))
                .foregroundStyle(page.colorName == "accent" ? WidgetSharedConstants.Color.blue : WidgetSharedConstants.Color.purple)
                .frame(width: WidgetVisualConstants.rowIconSize, height: WidgetVisualConstants.rowIconSize)
                .background(Color.white.opacity(WidgetVisualConstants.opacitySubtle))
                .clipShape(RoundedRectangle(cornerRadius: WidgetVisualConstants.microCornerRadius))

            Text(page.title)
                .font(.footnote.bold())
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: WidgetVisualConstants.chevronFontSize, weight: .bold))
                .foregroundStyle(.secondary.opacity(WidgetVisualConstants.opacityHalf))
        }
        .padding(.vertical, WidgetVisualConstants.verticalPadding)
        .padding(.horizontal, WidgetVisualConstants.horizontalPadding)
        .background(Color.white.opacity(WidgetVisualConstants.opacityFaint))
        .clipShape(RoundedRectangle(cornerRadius: WidgetVisualConstants.widgetCornerRadius))
    }
}

// MARK: - Widget Definition
/// 智宇静态桌面小组件定义
struct KnowledgeStatsWidget: Widget {
    let kind: String = "KnowledgeStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KnowledgeStatsProvider()) { entry in
            KnowledgeStatsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetL10n.title)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

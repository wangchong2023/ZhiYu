//
//  WidgetRepository.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：Widget Extension 专用 Repository，从 App Group JSON 快照读取数据。
//           遵循 Model (WidgetModels) + Repository 模式。

import Foundation

/// Widget 专用数据仓储
enum WidgetRepository {

    // MARK: - 路径解析

    private static let appGroupID = "group.com.zhiyu.app"

    private static var groupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static var widgetStatsURL: URL? {
        groupURL?.appendingPathComponent("widget_stats.json")
    }

    // MARK: - 查询 API（从 App Group JSON 快照读取，由主 App 写入）

    static func fetchStats() async -> WidgetStats {
        guard let url = widgetStatsURL,
              let data = try? Data(contentsOf: url),
              let stats = try? JSONDecoder().decode(WidgetStats.self, from: data) else {
            return WidgetStats(pageCount: 0, linkCount: 0, tagCount: 0)
        }
        return stats
    }

    static func fetchRecentPages(limit: Int = 3) async -> [WidgetRecentPage] {
        guard let url = widgetStatsURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetStatsSnapshot.self, from: data) else {
            return []
        }
        return Array(snapshot.recentPages.prefix(limit))
    }

    static func fetchDailyInsight() async -> WidgetDailyInsight {
        guard let url = widgetStatsURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetStatsSnapshot.self, from: data) else {
            return WidgetDailyInsight(
                title: WidgetL10n.llmWikiChunking,
                content: WidgetL10n.llmWikiDescription,
                flashThoughtSummary: WidgetL10n.flashThoughtSub
            )
        }
        return WidgetDailyInsight(
            title: snapshot.dailyInsightTitle ?? WidgetL10n.llmWikiChunking,
            content: snapshot.dailyInsightContent ?? WidgetL10n.llmWikiDescription,
            flashThoughtSummary: snapshot.flashThoughtSummary ?? WidgetL10n.flashThoughtSub
        )
    }

    static func fetchDistribution() async -> WidgetDistributionStats {
        guard let url = widgetStatsURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetStatsSnapshot.self, from: data),
              let dist = snapshot.distribution else {
            return WidgetDistributionStats(
                sourceRatio: 0.4,
                conceptRatio: 0.3,
                entityRatio: 0.2,
                mapRatio: 0.1,
                weeklyGrowth: 18
            )
        }
        return WidgetDistributionStats(
            sourceRatio: dist["source"] ?? 0.4,
            conceptRatio: dist["concept"] ?? 0.3,
            entityRatio: dist["entity"] ?? 0.2,
            mapRatio: dist["map"] ?? 0.1,
            weeklyGrowth: 18
        )
    }
}

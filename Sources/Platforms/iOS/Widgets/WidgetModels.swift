//
//  WidgetModels.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：Widget Extension 专用的轻量级 GRDB 数据行模型。
//           无法引入主 App 的 KnowledgePage/PageLink 领域模型，
//           故按 Repository 模式定义最小化 TableRecord + FetchableRecord。
//
import Foundation
@preconcurrency import GRDB

// MARK: - 页面行模型

/// Widget 专用的页面数据行，仅包含小组件渲染所需的列
struct WidgetPageRow: Codable {
    var title: String
    var pageType: String
    var tags: String?

    enum CodingKeys: String, CodingKey {
        case title
        case pageType = "page_type"
        case tags
    }
}

// MARK: GRDB TableRecord

extension WidgetPageRow: TableRecord {
    static let databaseTableName = AppConstants.Storage.Tables.pages

    enum Columns: String, ColumnExpression {
        case title
        case pageType = "page_type"
        case tags
        case updatedAt = "updated_at"
    }
}

// MARK: GRDB FetchableRecord

extension WidgetPageRow: FetchableRecord { }

// MARK: - 链接行模型

/// Widget 专用的链接数据行，用于链接计数
struct WidgetLinkRow: Codable {
    // 无需显式列，仅用于 fetchCount
}

// MARK: GRDB TableRecord

extension WidgetLinkRow: TableRecord {
    static let databaseTableName = AppConstants.Storage.Tables.links
}

// MARK: GRDB FetchableRecord

extension WidgetLinkRow: FetchableRecord { }

// MARK: - 全局设置行模型

/// Widget 专用的全局配置行，用于读取当前活跃 vault
struct WidgetGlobalSettingRow: Codable {
    var key: String
    var value: String

    enum CodingKeys: String, CodingKey {
        case key
        case value
    }
}

// MARK: GRDB TableRecord

extension WidgetGlobalSettingRow: TableRecord {
    static let databaseTableName = "global_settings"

    enum Columns: String, ColumnExpression {
        case key
        case value
    }
}

// MARK: GRDB FetchableRecord

extension WidgetGlobalSettingRow: FetchableRecord { }

// MARK: - 返回值模型

/// 知识库统计数据
struct WidgetStats: Codable {
    let pageCount: Int
    let linkCount: Int
    let tagCount: Int
}

/// 最近更新的知识页摘要
struct WidgetRecentPage: Codable {
    let title: String
    let typeName: String
    let colorName: String
}

/// 每日 AI 洞察与炼化金句
struct WidgetDailyInsight: Codable {
    let title: String
    let content: String
    let flashThoughtSummary: String
}

/// 知识库分类比例与热度分布
struct WidgetDistributionStats: Codable {
    let sourceRatio: Double
    let conceptRatio: Double
    let entityRatio: Double
    let mapRatio: Double
    let weeklyGrowth: Int
}

/// Widget 统计数据快照（主 App 写入 App Group JSON，Widget Extension 只读）
struct WidgetStatsSnapshot: Codable {
    let pageCount: Int
    let linkCount: Int
    let tagCount: Int
    let dailyInsightTitle: String?
    let dailyInsightContent: String?
    let flashThoughtSummary: String?
    let distribution: [String: Double]?
    let recentPages: [WidgetRecentPage]
}

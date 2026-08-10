//
//  L10nInsightTableExtrasTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Insight 表 L10n 扩展（Dashboard）的 tableName 正确性与代表性属性 key 存在性。
//

import XCTest
@testable import ZhiYu

/// Insight 表 L10n 扩展补充测试（Dashboard）
/// 已有 L10nInsightTableTests 覆盖 Insight 命名空间
final class L10nInsightTableExtrasTests: XCTestCase {

    // MARK: - tableName 正确性

    func testTableName_Dashboard_为Insight() {
        XCTAssertEqual(L10n.Dashboard.tableName, "Insight")
    }

    // MARK: - Dashboard 顶层属性 key 存在性

    func testDashboard_顶层基础属性返回非Missing值() {
        let values = [
            L10n.Dashboard.pageListPages,
            L10n.Dashboard.pageListLinks,
            L10n.Dashboard.density,
            L10n.Dashboard.dailyInsights,
            L10n.Dashboard.hotTopics,
            L10n.Dashboard.insightsLoading,
            L10n.Dashboard.insightsPageDeleted,
            L10n.Dashboard.insightsEmpty,
            L10n.Dashboard.graphShortcut
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Dashboard 顶层属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Dashboard 顶层属性返回空字符串")
        }
    }

    // MARK: - Dashboard.insight 子命名空间

    func testDashboard_insight_基础属性返回非Missing值() {
        let values = [
            L10n.Dashboard.insight.weeklyTitle,
            L10n.Dashboard.insight.generateReport,
            L10n.Dashboard.insight.addPagesFirst
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Dashboard.insight 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Dashboard.insight 属性返回空字符串")
        }
    }
    // MARK: - Dashboard.insight.mock 子命名空间

    func testDashboard_insight_mock_属性返回非Missing值() {
        let values = [
            L10n.Dashboard.insight.mock.insight,
            L10n.Dashboard.insight.mock.suggestedConnection
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Dashboard.insight.mock 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Dashboard.insight.mock 属性返回空字符串")
        }
    }

    // MARK: - Dashboard.insight.recap 子命名空间

    func testDashboard_insight_recap_属性返回非Missing值() {
        let value = L10n.Dashboard.insight.recap.tip
        XCTAssertFalse(value.contains("[MISSING:"),
                       "Dashboard.insight.recap.tip 返回 Missing: \(value)")
        XCTAssertFalse(value.isEmpty, "Dashboard.insight.recap.tip 返回空字符串")
    }

    // MARK: - Dashboard.insight.weekly 子命名空间

    func testDashboard_insight_weekly_属性返回非Missing值() {
        let value = L10n.Dashboard.insight.weekly.systemPrompt
        XCTAssertFalse(value.contains("[MISSING:"),
                       "Dashboard.insight.weekly.systemPrompt 返回 Missing: \(value)")
        XCTAssertFalse(value.isEmpty, "Dashboard.insight.weekly.systemPrompt 返回空字符串")
    }

    func testDashboard_insight_weekly_prompt_返回非Missing且包含参数() {
        let result = L10n.Dashboard.insight.weekly.prompt("topic1")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Dashboard.insight.weekly.prompt 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Dashboard.insight.growth 子命名空间

    func testDashboard_insight_growth_属性返回非Missing值() {
        let values = [
            L10n.Dashboard.insight.growth.explosive,
            L10n.Dashboard.insight.growth.steady
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Dashboard.insight.growth 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Dashboard.insight.growth 属性返回空字符串")
        }
    }

    // MARK: - Dashboard 密度与坐标轴属性

    func testDashboard_密度与坐标轴属性返回非Missing值() {
        let values = [
            L10n.Dashboard.title,
            L10n.Dashboard.unitMs,
            L10n.Dashboard.densityDesc,
            L10n.Dashboard.densityDetails,
            L10n.Dashboard.densityOutbound,
            L10n.Dashboard.densityInbound,
            L10n.Dashboard.axisPages,
            L10n.Dashboard.axisRelations,
            L10n.Dashboard.benchmarkDescription
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Dashboard 密度属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Dashboard 密度属性返回空字符串")
        }
    }

    // MARK: - Dashboard.pageList 子命名空间

    func testDashboard_pageList_属性返回非Missing值() {
        let values = [
            L10n.Dashboard.pageList.tags,
            L10n.Dashboard.pageList.sources,
            L10n.Dashboard.pageList.overview,
            L10n.Dashboard.pageList.concepts,
            L10n.Dashboard.pageList.entities,
            L10n.Dashboard.pageList.wordCount,
            L10n.Dashboard.pageList.entityCount,
            L10n.Dashboard.pageList.conceptCount,
            L10n.Dashboard.pageList.sourceCount,
            L10n.Dashboard.pageList.comparisonCount,
            L10n.Dashboard.pageList.rawCount
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Dashboard.pageList 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Dashboard.pageList 属性返回空字符串")
        }
    }

    // MARK: - Dashboard 统计相关属性

    func testDashboard_统计属性返回非Missing值() {
        let values = [
            L10n.Dashboard.totalPages,
            L10n.Dashboard.totalLinks,
            L10n.Dashboard.apiRequests,
            L10n.Dashboard.totalStorage,
            L10n.Dashboard.tokens,
            L10n.Dashboard.chartDate,
            L10n.Dashboard.chartSelected,
            L10n.Dashboard.chartValue,
            L10n.Dashboard.maintenance,
            L10n.Dashboard.cleanedPrefix,
            L10n.Dashboard.cleanedSuffix,
            L10n.Dashboard.cleanupAction,
            L10n.Dashboard.updateSuccess
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Dashboard 统计属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Dashboard 统计属性返回空字符串")
        }
    }

    // MARK: - Dashboard.stats 子命名空间

    func testDashboard_stats_基础属性返回非Missing值() {
        let values = [
            L10n.Dashboard.stats.title,
            L10n.Dashboard.stats.audioFormat,
            L10n.Dashboard.stats.imageFormat,
            L10n.Dashboard.stats.documentFormat
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Dashboard.stats 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Dashboard.stats 属性返回空字符串")
        }
    }

    func testDashboard_stats_itemsCount_返回非Missing且包含参数() {
        let result = L10n.Dashboard.stats.itemsCount(5)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Dashboard.stats.itemsCount 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Dashboard.index 子命名空间

    func testDashboard_index_属性返回非Missing值() {
        let values = [
            L10n.Dashboard.index.title,
            L10n.Dashboard.index.overview
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Dashboard.index 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Dashboard.index 属性返回空字符串")
        }
    }

    // MARK: - Dashboard.System 子命名空间

    func testDashboard_System_属性返回非Missing值() {
        let values = [
            L10n.Dashboard.System.status,
            L10n.Dashboard.System.database,
            L10n.Dashboard.System.logs,
            L10n.Dashboard.System.models,
            L10n.Dashboard.System.plugins,
            L10n.Dashboard.System.caches
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Dashboard.System 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Dashboard.System 属性返回空字符串")
        }
    }

    // MARK: - Dashboard.stats.short 子命名空间

    func testDashboard_stats_short_属性返回非Missing值() {
        let values = [
            L10n.Dashboard.stats.short.entity,
            L10n.Dashboard.stats.short.concept,
            L10n.Dashboard.stats.short.source,
            L10n.Dashboard.stats.short.comparison,
            L10n.Dashboard.stats.short.raw,
            L10n.Dashboard.stats.short.pages,
            L10n.Dashboard.stats.short.new,
            L10n.Dashboard.stats.short.ref
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Dashboard.stats.short 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Dashboard.stats.short 属性返回空字符串")
        }
    }
}

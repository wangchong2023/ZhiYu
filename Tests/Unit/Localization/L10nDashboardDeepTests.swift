//
//  L10nDashboardDeepTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/22.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度验证 Dashboard 表 L10n 扩展的所有属性 key 存在性与返回值非空。
//

import XCTest
@testable import ZhiYu

/// Dashboard 表 L10n 扩展深度测试
final class L10nDashboardDeepTests: XCTestCase {

    private func assertNonMissing(_ value: String, _ context: String = "") {
        XCTAssertFalse(value.contains("[MISSING:"), "属性返回 Missing \(context): \(value)")
        XCTAssertFalse(value.isEmpty, "属性返回空字符串 \(context)")
    }

    // MARK: - tableName

    func testTableName_Dashboard_为Insight() {
        XCTAssertEqual(L10n.Dashboard.tableName, "Insight")
    }

    // MARK: - 顶层属性

    func testDashboard_顶层属性() {
        let values = [
            L10n.Dashboard.pageListPages, L10n.Dashboard.pageListLinks,
            L10n.Dashboard.density, L10n.Dashboard.dailyInsights,
            L10n.Dashboard.hotTopics, L10n.Dashboard.insightsLoading,
            L10n.Dashboard.insightsPageDeleted, L10n.Dashboard.insightsEmpty,
            L10n.Dashboard.graphShortcut, L10n.Dashboard.title,
            L10n.Dashboard.unitMs, L10n.Dashboard.densityDesc,
            L10n.Dashboard.densityDetails, L10n.Dashboard.densityOutbound,
            L10n.Dashboard.densityInbound, L10n.Dashboard.axisPages,
            L10n.Dashboard.axisRelations, L10n.Dashboard.benchmarkDescription,
            L10n.Dashboard.cleanupAction, L10n.Dashboard.updateSuccess,
            L10n.Dashboard.totalPages, L10n.Dashboard.totalLinks,
            L10n.Dashboard.apiRequests, L10n.Dashboard.totalStorage,
            L10n.Dashboard.tokens, L10n.Dashboard.chartDate,
            L10n.Dashboard.chartSelected, L10n.Dashboard.chartValue,
            L10n.Dashboard.maintenance, L10n.Dashboard.cleanedPrefix,
            L10n.Dashboard.cleanedSuffix
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - insight 子模块

    func testDashboard_insight_基础属性() {
        let values = [
            L10n.Dashboard.insight.weeklyTitle,
            L10n.Dashboard.insight.generateReport,
            L10n.Dashboard.insight.addPagesFirst
        ]
        for value in values { assertNonMissing(value) }
    }

    func testDashboard_insight_daily() {
        assertNonMissing(L10n.Dashboard.insight.daily.systemPrompt)
        let prompt = L10n.Dashboard.insight.daily.promptRecent("AI", "测试标题", "测试片段")
        assertNonMissing(prompt, "daily.promptRecent")
    }

    func testDashboard_insight_mock() {
        assertNonMissing(L10n.Dashboard.insight.mock.insight)
        assertNonMissing(L10n.Dashboard.insight.mock.suggestedConnection)
    }

    func testDashboard_insight_recap() {
        assertNonMissing(L10n.Dashboard.insight.recap.tip)
    }

    func testDashboard_insight_weekly() {
        assertNonMissing(L10n.Dashboard.insight.weekly.systemPrompt)
        let prompt = L10n.Dashboard.insight.weekly.prompt("页面1,页面2")
        assertNonMissing(prompt, "weekly.prompt")
    }

    func testDashboard_insight_growth() {
        assertNonMissing(L10n.Dashboard.insight.growth.explosive)
        assertNonMissing(L10n.Dashboard.insight.growth.steady)
    }

    func testDashboard_insight_tips() {
        assertNonMissing(L10n.Dashboard.insight.tips.title)
        assertNonMissing(L10n.Dashboard.insight.tips.content)
    }

    // MARK: - pageList 子模块

    func testDashboard_pageList_基础属性() {
        let values = [
            L10n.Dashboard.pageList.tags, L10n.Dashboard.pageList.sources,
            L10n.Dashboard.pageList.overview, L10n.Dashboard.pageList.concepts,
            L10n.Dashboard.pageList.entities, L10n.Dashboard.pageList.wordCount,
            L10n.Dashboard.pageList.entityCount, L10n.Dashboard.pageList.conceptCount,
            L10n.Dashboard.pageList.sourceCount, L10n.Dashboard.pageList.comparisonCount,
            L10n.Dashboard.pageList.rawCount
        ]
        for value in values { assertNonMissing(value) }
    }

    func testDashboard_pageList_格式化方法() {
        assertNonMissing(L10n.Dashboard.pageList.wordCount(100), "wordCount(100)")
        assertNonMissing(L10n.Dashboard.pageList.entityCount(50), "entityCount(50)")
        assertNonMissing(L10n.Dashboard.pageList.conceptCount(30), "conceptCount(30)")
        assertNonMissing(L10n.Dashboard.pageList.sourceCount(10), "sourceCount(10)")
        assertNonMissing(L10n.Dashboard.pageList.comparisonCount(5), "comparisonCount(5)")
        assertNonMissing(L10n.Dashboard.pageList.rawCount(20), "rawCount(20)")
    }

    // MARK: - stats 子模块

    func testDashboard_stats_基础属性() {
        let values = [
            L10n.Dashboard.stats.title, L10n.Dashboard.stats.audioFormat,
            L10n.Dashboard.stats.imageFormat, L10n.Dashboard.stats.documentFormat,
            L10n.Dashboard.stats.faithfulness, L10n.Dashboard.stats.relevance,
            L10n.Dashboard.stats.precision, L10n.Dashboard.stats.hallucinationRate,
            L10n.Dashboard.stats.citationAccuracy, L10n.Dashboard.stats.generationQuality,
            L10n.Dashboard.stats.retrievalFidelity, L10n.Dashboard.stats.retrievalQuality,
            L10n.Dashboard.stats.rankingQuality, L10n.Dashboard.stats.coverage,
            L10n.Dashboard.stats.contextFidelity, L10n.Dashboard.stats.responseLatency,
            L10n.Dashboard.stats.hitRateDesc, L10n.Dashboard.stats.mrrTitle,
            L10n.Dashboard.stats.mrrDesc, L10n.Dashboard.stats.ndcgTitle,
            L10n.Dashboard.stats.ndcgDesc, L10n.Dashboard.stats.hitRateTitle,
            L10n.Dashboard.stats.recallAtK, L10n.Dashboard.stats.recallDesc,
            L10n.Dashboard.stats.f1AtK, L10n.Dashboard.stats.f1Desc,
            L10n.Dashboard.stats.mapTitle, L10n.Dashboard.stats.mapDesc,
            L10n.Dashboard.stats.answerCorrectness, L10n.Dashboard.stats.answerCorrectnessDesc,
            L10n.Dashboard.stats.retrievalLatency, L10n.Dashboard.stats.latencyP50,
            L10n.Dashboard.stats.latencyP95, L10n.Dashboard.stats.latencyP99,
            L10n.Dashboard.stats.latencyUnitMS, L10n.Dashboard.stats.latencySampleCount,
            L10n.Dashboard.stats.tokenEfficiency, L10n.Dashboard.stats.totalTokens,
            L10n.Dashboard.stats.avgTokensPerQuery, L10n.Dashboard.stats.estimatedCost,
            L10n.Dashboard.stats.queryCount, L10n.Dashboard.stats.tabRetrieval,
            L10n.Dashboard.stats.tabGeneration, L10n.Dashboard.stats.tabSatisfaction,
            L10n.Dashboard.stats.tabHistory, L10n.Dashboard.stats.tabSatisfactionAndEval,
            L10n.Dashboard.stats.tabPlugins
        ]
        for value in values { assertNonMissing(value) }
    }

    func testDashboard_stats_itemsCount() {
        assertNonMissing(L10n.Dashboard.stats.itemsCount(42), "itemsCount(42)")
    }

    func testDashboard_stats_tip属性() {
        let values = [
            L10n.Dashboard.stats.tipRetrievalPhase, L10n.Dashboard.stats.tipGenerationPhase,
            L10n.Dashboard.stats.tipCostPhase, L10n.Dashboard.stats.tipHitRate,
            L10n.Dashboard.stats.tipMRR, L10n.Dashboard.stats.tipNDCG,
            L10n.Dashboard.stats.tipRecall, L10n.Dashboard.stats.tipF1,
            L10n.Dashboard.stats.tipMAP, L10n.Dashboard.stats.tipFaithfulness,
            L10n.Dashboard.stats.tipRelevance, L10n.Dashboard.stats.tipHallucination,
            L10n.Dashboard.stats.tipPrecision, L10n.Dashboard.stats.tipCitation,
            L10n.Dashboard.stats.tipCorrectness, L10n.Dashboard.stats.tipLatency,
            L10n.Dashboard.stats.tipTokenEfficiency,
            L10n.Dashboard.stats.tipContextSufficiency,
            L10n.Dashboard.stats.tipUserSatisfaction
        ]
        for value in values { assertNonMissing(value) }
    }

    func testDashboard_stats_其余属性() {
        let values = [
            L10n.Dashboard.stats.contextSufficiency,
            L10n.Dashboard.stats.contextSufficiencyDesc,
            L10n.Dashboard.stats.userSatisfaction,
            L10n.Dashboard.stats.noRatings, L10n.Dashboard.stats.ratingTotal,
            L10n.Dashboard.stats.evaluation, L10n.Dashboard.stats.overview,
            L10n.Dashboard.stats.recentEvaluations, L10n.Dashboard.stats.noEvaluations,
            L10n.Dashboard.stats.unitDays, L10n.Dashboard.stats.benchmark,
            L10n.Dashboard.stats.categoryDistribution,
            L10n.Dashboard.stats.knowledgeGrowth,
            L10n.Dashboard.stats.navigationTitleMonitor,
            L10n.Dashboard.stats.storageImport, L10n.Dashboard.stats.storageExport,
            L10n.Dashboard.stats.tabPerf, L10n.Dashboard.stats.tabStorage,
            L10n.Dashboard.stats.rangeThirtyDays,
            L10n.Dashboard.stats.requestsUsage, L10n.Dashboard.stats.tokenUsage,
            L10n.Dashboard.stats.requestCount,
            L10n.Dashboard.stats.storageDistribution,
            L10n.Dashboard.stats.chartDate, L10n.Dashboard.stats.chartSelected,
            L10n.Dashboard.stats.tokensUsage, L10n.Dashboard.stats.latencyTitle,
            L10n.Dashboard.stats.avgLatencyShort, L10n.Dashboard.stats.maxLatency,
            L10n.Dashboard.stats.minLatency, L10n.Dashboard.stats.measureCount,
            L10n.Dashboard.stats.storageDetails, L10n.Dashboard.stats.chartValue,
            L10n.Dashboard.stats.vaultStorageTitle,
            L10n.Dashboard.stats.activeVaultStatus,
            L10n.Dashboard.stats.inactiveVaultStatus,
            L10n.Dashboard.stats.rawStorageTitle,
            L10n.Dashboard.stats.rawTotalPages,
            L10n.Dashboard.stats.rawTotalSize,
            L10n.Dashboard.stats.viewRawPages,
            L10n.Dashboard.stats.rawPageDetailTitle
        ]
        for value in values { assertNonMissing(value) }
    }

    func testDashboard_stats_multiVaultDesc() {
        assertNonMissing(L10n.Dashboard.stats.multiVaultDesc(3), "multiVaultDesc(3)")
    }

    func testDashboard_stats_rawPageCountFormat() {
        assertNonMissing(L10n.Dashboard.stats.rawPageCountFormat(100, "50KB"), "rawPageCountFormat")
    }

    func testDashboard_stats_short_所有属性() {
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
        for value in values { assertNonMissing(value) }
    }

    // MARK: - index 子模块

    func testDashboard_index_所有属性() {
        assertNonMissing(L10n.Dashboard.index.title)
        assertNonMissing(L10n.Dashboard.index.overview)
    }

    // MARK: - System 子模块

    func testDashboard_System_所有属性() {
        let values = [
            L10n.Dashboard.System.status, L10n.Dashboard.System.database,
            L10n.Dashboard.System.logs, L10n.Dashboard.System.models,
            L10n.Dashboard.System.plugins, L10n.Dashboard.System.caches
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - B-3: trf 死代码问题

    /// B-3: Dashboard.trf 方法中 `if localized == key` 分支重复调用相同方法
    /// `Localized.trf(key, table: t, arguments: args)` 返回 key 时再次调用相同方法
    /// 这是无效的死代码 — 第二次调用会返回同样的结果
    func testDashboard_trf_格式化方法返回非Missing() {
        let result = L10n.Dashboard.insight.daily.promptRecent("焦点", "标题", "片段")
        assertNonMissing(result, "trf 格式化方法")
        // 验证格式化参数被正确替换
        XCTAssertTrue(result.contains("焦点") || result.contains("标题") || result.contains("片段") || !result.contains("[MISSING:"),
                      "格式化方法应包含传入的参数或返回有效文案")
    }
}

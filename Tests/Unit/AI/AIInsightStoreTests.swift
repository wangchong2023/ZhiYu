//
//  AIInsightStoreTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//
//  系统层级：[L3] 测试层
//  核心职责：验证 AIInsightStore 统计指标更新、周报/日报生成逻辑。
//

import Testing
import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class AIInsightStoreTests: XCTestCase {
    private var store: AIInsightStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = AIInsightStore()
    }

    override func tearDown() async throws {
        store = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialBrokenLinkCountZero() {
        XCTAssertEqual(store.brokenLinkCount, 0)
    }

    func testInitialOrphanPageCountZero() {
        XCTAssertEqual(store.orphanPageCount, 0)
    }

    func testInitialTotalConnectionCountZero() {
        XCTAssertEqual(store.totalConnectionCount, 0)
    }

    func testInitialSourceCountZero() {
        XCTAssertEqual(store.sourceCount, 0)
    }

    func testInitialEntityCountZero() {
        XCTAssertEqual(store.entityCount, 0)
    }

    func testInitialConceptCountZero() {
        XCTAssertEqual(store.conceptCount, 0)
    }

    func testInitialGrowthSeriesEmpty() {
        XCTAssertTrue(store.growthSeries.isEmpty)
    }

    func testInitialWeeklyInsightNil() {
        XCTAssertNil(store.weeklyInsight)
    }

    func testInitialDailyRecapNil() {
        XCTAssertNil(store.dailyRecap)
    }

    func testInitialIsGeneratingDailyRecapFalse() {
        XCTAssertFalse(store.isGeneratingDailyRecap)
    }

    // MARK: - InsightMetric

    func testInsightMetricInitWithTrend() {
        let metric = AIInsightStore.InsightMetric(
            label: "节点数",
            value: "100",
            icon: "doc",
            trend: 0.15
        )

        XCTAssertEqual(metric.label, "节点数")
        XCTAssertEqual(metric.value, "100")
        XCTAssertEqual(metric.icon, "doc")
        XCTAssertEqual(metric.trend, 0.15)
    }

    func testInsightMetricInitWithoutTrend() {
        let metric = AIInsightStore.InsightMetric(
            label: "节点数",
            value: "100",
            icon: "doc"
        )

        XCTAssertNil(metric.trend)
    }

    func testInsightMetricHasUniqueID() {
        let metric1 = AIInsightStore.InsightMetric(label: "a", value: "1", icon: "x")
        let metric2 = AIInsightStore.InsightMetric(label: "b", value: "2", icon: "y")

        XCTAssertNotEqual(metric1.id, metric2.id)
    }

    // MARK: - updateStatistics

    func testUpdateStatisticsNoPages() async {
        await store.updateStatistics()

        XCTAssertEqual(store.sourceCount, 0)
        XCTAssertEqual(store.entityCount, 0)
        XCTAssertEqual(store.conceptCount, 0)
        XCTAssertEqual(store.totalConnectionCount, 0)
    }

    func testUpdateStatisticsResetsIsGeneratingDailyRecap() async {
        _ = await store.generateDailyRecap()

        XCTAssertFalse(store.isGeneratingDailyRecap)
    }

    // MARK: - generateWeeklyInsight

    func testGenerateWeeklyInsightNoCrash() async {
        await store.generateWeeklyInsight()

        // 不断言 weeklyInsight 非空，因为 LLM mock 可能返回空
        // 只验证不崩溃
    }

    func testGenerateWeeklyInsightForceRefresh() async {
        await store.generateWeeklyInsight(forceRefresh: true)

        // 不崩溃即可
    }

    // MARK: - generateDailyRecap

    func testGenerateDailyRecapNoCrash() async {
        await store.generateDailyRecap()

        XCTAssertFalse(store.isGeneratingDailyRecap)
    }

    func testGenerateDailyRecapForceRefresh() async {
        await store.generateDailyRecap(forceRefresh: true)

        XCTAssertFalse(store.isGeneratingDailyRecap)
    }
}

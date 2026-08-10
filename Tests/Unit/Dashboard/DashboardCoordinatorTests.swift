//
//  DashboardCoordinatorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 DashboardCoordinator 的标签聚合、反链统计、密度 Top N 排序与 AI 洞察刷新联动状态。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class DashboardCoordinatorTests: XCTestCase {

    /// 被测协调器实例
    private var coordinator: DashboardCoordinator!

    /// 全局数据仓库实例
    private var store: AppStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = AppStore()
        coordinator = DashboardCoordinator()
    }

    override func tearDown() async throws {
        coordinator = nil
        store = nil
        try? await Task.sleep(nanoseconds: 50_000_000)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 初始化状态

    /// 验证协调器初始化默认状态
    func testInitializationDefaults() {
        XCTAssertTrue(coordinator.tags.isEmpty, "初始化时标签集合应为空")
        XCTAssertEqual(coordinator.totalLinks, 0, "初始化时总链接数应为 0")
        XCTAssertTrue(coordinator.densityData.isEmpty, "初始化时密度数据应为空")
        XCTAssertFalse(coordinator.isCalculating, "初始化时计算状态应为 false")
        XCTAssertFalse(coordinator.isGeneratingInsights, "初始化时洞察生成状态应为 false")
        XCTAssertNil(coordinator.dailyRecap, "初始化时每日灵感应为 nil")
    }

    // MARK: - updateTags 标签聚合

    /// 验证空页面库时 updateTags 不产生标签
    func testUpdateTagsEmptyStore() {
        coordinator.updateTags()
        XCTAssertTrue(coordinator.tags.isEmpty, "空页面库时标签集合应保持为空")
    }

    /// 验证多页面多标签的聚合与按计数降序排序
    func testUpdateTagsAggregatesAndSortsByCount() async {
        _ = await store.createPage(title: "P1", pageType: .concept, content: "c1", tags: ["Swift", "iOS"])
        _ = await store.createPage(title: "P2", pageType: .concept, content: "c2", tags: ["Swift", "SwiftUI"])
        _ = await store.createPage(title: "P3", pageType: .concept, content: "c3", tags: ["Swift"])

        coordinator.updateTags()

        XCTAssertEqual(coordinator.tags.count, 3, "应聚合出 3 个唯一标签")
        XCTAssertEqual(coordinator.tags.first?.tag, "Swift", "Swift 出现 3 次应排在首位")
        XCTAssertEqual(coordinator.tags.first?.count, 3, "Swift 计数应为 3")
        XCTAssertEqual(coordinator.tags.last?.count, 1, "末位标签计数应为 1")
    }

    /// 验证内容中的 #标签 也能被 getAllTags 提取并聚合
    func testUpdateTagsIncludesContentHashtags() async {
        _ = await store.createPage(title: "P1", pageType: .concept, content: "正文 #Markdown 备注", tags: [])

        coordinator.updateTags()

        XCTAssertTrue(coordinator.tags.contains { $0.tag == "Markdown" }, "应从内容中提取 #Markdown 标签")
    }

    // MARK: - calculateStats 统计计算

    /// 验证空页面库时 calculateStats 重置统计
    func testCalculateStatsEmptyStore() async {
        await coordinator.calculateStats()
        XCTAssertEqual(coordinator.totalLinks, 0, "空库时总链接数应为 0")
        XCTAssertTrue(coordinator.densityData.isEmpty, "空库时密度数据应为空")
    }

    /// 验证反链统计与总链接数计算
    func testCalculateStatsBacklinksAndTotalLinks() async {
        // P1 链接到 P2、P3；P2 链接到 P1
        _ = await store.createPage(title: "P1", pageType: .concept, content: "[[P2]] [[P3]]", tags: [])
        _ = await store.createPage(title: "P2", pageType: .concept, content: "[[P1]]", tags: [])
        _ = await store.createPage(title: "P3", pageType: .concept, content: "", tags: [])

        await coordinator.calculateStats()

        // 总链接数 = P1(2) + P2(1) + P3(0) = 3
        XCTAssertEqual(coordinator.totalLinks, 3, "总链接数应为 3")
        // P1 入链 1（来自 P2）+ 出链 2 = 3，应排首位
        XCTAssertEqual(coordinator.densityData.first?.name, "P1", "P1 密度最高应排首位")
        XCTAssertEqual(coordinator.densityData.first?.inbound, 1.0, "P1 入链应为 1")
        XCTAssertEqual(coordinator.densityData.first?.outbound, 2.0, "P1 出链应为 2")
    }

    /// 验证密度数据只保留 Top 5
    func testCalculateStatsDensityTopN() async {
        // 创建 7 个页面，确保 densityData 被截断为 5
        for i in 1...7 {
            _ = await store.createPage(title: "P\(i)", pageType: .concept, content: "[[P\(i + 1)]]", tags: [])
        }

        await coordinator.calculateStats()

        XCTAssertEqual(coordinator.densityData.count, 5, "密度数据应只保留 Top 5")
    }

    /// 验证密度排序按 inbound + outbound 降序
    func testCalculateStatsDensitySortedDescending() async {
        _ = await store.createPage(title: "Low", pageType: .concept, content: "", tags: [])
        _ = await store.createPage(title: "High", pageType: .concept, content: "[[Low]] [[Mid]]", tags: [])
        _ = await store.createPage(title: "Mid", pageType: .concept, content: "[[Low]]", tags: [])

        await coordinator.calculateStats()

        let scores = coordinator.densityData.map { $0.inbound + $0.outbound }
        XCTAssertEqual(scores, scores.sorted(by: >), "密度数据应按总分降序排列")
    }

    // MARK: - refreshAll 全量刷新

    /// 验证 refreshAll 在空库时正确重置状态并完成
    func testRefreshAllEmptyStore() async {
        await coordinator.refreshAll()
        XCTAssertEqual(coordinator.totalLinks, 0, "空库刷新后总链接数应为 0")
        XCTAssertTrue(coordinator.tags.isEmpty, "空库刷新后标签应为空")
        XCTAssertFalse(coordinator.isCalculating, "刷新完成后 isCalculating 应重置为 false")
    }

    /// 验证 refreshAll 有数据时填充所有状态
    func testRefreshAllPopulatesAllStates() async {
        _ = await store.createPage(title: "P1", pageType: .concept, content: "[[P2]]", tags: ["Swift"])
        _ = await store.createPage(title: "P2", pageType: .concept, content: "", tags: ["Swift", "iOS"])

        await coordinator.refreshAll()

        XCTAssertEqual(coordinator.totalLinks, 1, "总链接数应为 1")
        XCTAssertEqual(coordinator.tags.count, 2, "标签应聚合为 2 个")
        XCTAssertFalse(coordinator.isCalculating, "刷新完成后 isCalculating 应重置")
        // dailyRecap 在 Mock LLM 下可能为 nil（生成失败），但状态应已同步
        XCTAssertFalse(coordinator.isGeneratingInsights, "刷新完成后洞察生成状态应重置")
    }

    // MARK: - refreshInsights 洞察刷新

    /// 验证 refreshInsights 同步 aiStore 的生成状态
    func testRefreshInsightsSyncsGeneratingState() async {
        await coordinator.refreshInsights()
        XCTAssertFalse(coordinator.isGeneratingInsights, "洞察刷新完成后生成状态应为 false")
    }

    /// 验证 refreshInsights 多次调用状态正确重置
    func testRefreshInsightsResetsAfterMultipleCalls() async {
        for _ in 0..<3 {
            await coordinator.refreshInsights()
            XCTAssertFalse(coordinator.isGeneratingInsights, "每次刷新后生成状态都应重置为 false")
        }
    }
}

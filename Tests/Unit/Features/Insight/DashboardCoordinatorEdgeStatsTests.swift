//
//  DashboardCoordinatorEdgeStatsTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class DashboardCoordinatorEdgeStatsTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. Empty State Stats & Tag Aggregation

    func testDashboardCoordinatorEmptyState() async throws {
        let store = AppStore()
        let coordinator = DashboardCoordinator()
        await coordinator.calculateStats(store: store)

        XCTAssertEqual(coordinator.totalLinks, 0)
        XCTAssertTrue(coordinator.densityData.isEmpty)

        coordinator.updateTags(store: store)
        XCTAssertTrue(coordinator.tags.isEmpty)
    }

    // MARK: - 2. Self-Loop & Multi-Link Graph Density Calculation

    func testDashboardCoordinatorGraphDensityWithSelfLoops() async throws {
        let store = AppStore()
        let coordinator = DashboardCoordinator()

        // 构造含自环引用与复杂拓扑的知识页面
        let page1 = KnowledgePage(
            title: "Hub Page",
            pageType: .concept,
            content: "Links to [[Hub Page]], [[Leaf A]], [[Leaf B]] and [[Leaf C]]",
            tags: ["Architecture", "Core"]
        )
        let page2 = KnowledgePage(
            title: "Leaf A",
            pageType: .concept,
            content: "Links back to [[Hub Page]]",
            tags: ["Architecture"]
        )
        let page3 = KnowledgePage(
            title: "Leaf B",
            pageType: .concept,
            content: "Isolated links",
            tags: ["Unrelated"]
        )

        await store.savePage(page1)
        await store.savePage(page2)
        await store.savePage(page3)

        // 触发全量计算
        await coordinator.refreshAll(store: store)

        XCTAssertFalse(coordinator.isCalculating)
        XCTAssertGreaterThan(coordinator.totalLinks, 0)
        XCTAssertFalse(coordinator.densityData.isEmpty)
        XCTAssertEqual(coordinator.densityData.first?.name, "Hub Page")

        // 验证标签排序
        XCTAssertFalse(coordinator.tags.isEmpty)
        XCTAssertEqual(coordinator.tags.first?.tag, "Architecture")
        XCTAssertEqual(coordinator.tags.first?.count, 2)
    }

    // MARK: - 3. AI Insights Sync Trigger

    func testDashboardCoordinatorAIInsightsSync() async throws {
        let coordinator = DashboardCoordinator()
        await coordinator.refreshInsights()
        XCTAssertFalse(coordinator.isGeneratingInsights)
    }
}

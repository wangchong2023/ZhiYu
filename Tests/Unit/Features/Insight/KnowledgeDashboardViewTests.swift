//
//  KnowledgeDashboardViewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 DashboardCoordinator 拓扑计算、连接密度 Top N 排序与标签词频聚合分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class KnowledgeDashboardViewTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 反链计算与连接密度 Top N 排序分支

    func testDashboardCoordinator_CalculateStatsAndDensity() async {
        let store = AppStore()

        let pageA = KnowledgePage(title: "分布式系统", pageType: .concept, content: "包含 [[CAP 定理]] 和 [[共识算法]]")
        let pageB = KnowledgePage(title: "CAP 定理", pageType: .concept, content: "参见 [[分布式系统]]")
        let pageC = KnowledgePage(title: "共识算法", pageType: .concept, content: "参见 [[分布式系统]]")

        await store.savePage(pageA)
        await store.savePage(pageB)
        await store.savePage(pageC)

        let coordinator = DashboardCoordinator()
        await coordinator.calculateStats()

        XCTAssertGreaterThan(coordinator.totalLinks, 0)
        XCTAssertFalse(coordinator.densityData.isEmpty)

        // 验证第一名密度的节点
        let topDensity = coordinator.densityData.first
        XCTAssertNotNil(topDensity)
        XCTAssertEqual(topDensity?.name, "分布式系统")
    }

    // MARK: - 2. 标签聚合与词频统计分支

    func testDashboardCoordinator_UpdateTagsFrequency() async {
        let store = AppStore()

        let page1 = KnowledgePage(title: "P1", pageType: .concept, content: "C1", tags: ["Swift", "iOS"])
        let page2 = KnowledgePage(title: "P2", pageType: .concept, content: "C2", tags: ["Swift", "Server"])

        await store.savePage(page1)
        await store.savePage(page2)

        let coordinator = DashboardCoordinator()
        coordinator.updateTags()

        XCTAssertFalse(coordinator.tags.isEmpty)
        let swiftTag = coordinator.tags.first { $0.tag == "Swift" }
        XCTAssertEqual(swiftTag?.count, 2)
    }
}

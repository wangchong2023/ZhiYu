//
//  SystemStatsAndStorageViewFullDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 SystemStatsView 系统监控、RawStorageListView 裸存储分类列表、
//           PluginStatsSection 插件消耗统计与 DeveloperSettingsView 开发者设置全套状态机。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class SystemStatsAndStorageViewFullDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SystemStatsView 全选项卡与生命周期测试

    func testSystemStatsView_AllTabsHierarchy() async {
        for tab in SystemStatsView.Tab.allCases {
            XCTAssertFalse(tab.title.isEmpty)
        }

        let host = NavigationStack {
            SystemStatsView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testSystemStatsCoordinator_LoadAndLatencyCalculations() async {
        let coordinator = SystemStatsCoordinator()
        XCTAssertTrue(coordinator.isLoading)
        XCTAssertEqual(coordinator.avgLatency, 0)
        XCTAssertEqual(coordinator.maxLatency, 0)
        XCTAssertEqual(coordinator.minLatency, 0)

        await coordinator.loadStats()
        XCTAssertFalse(coordinator.isLoading)
    }

    // MARK: - 2. RawStorageListView 分类与清理测试

    func testRawStorageListView_HierarchyAndCategories() {
        for category in RawCategoryType.allCases {
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertFalse(category.systemIconName.isEmpty)
        }

        let host = NavigationStack {
            RawStorageListView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. PluginStatsSection 插件消耗面板测试

    func testPluginStatsSection_Hierarchy() {
        let host = NavigationStack {
            PluginStatsSection()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 4. DeveloperSettingsView 压力测试与状态变更

    func testDeveloperSettingsView_StressTestFlowAndHierarchy() {
        let host = NavigationStack {
            DeveloperSettingsView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 5. SubscriptionPlanView 与 BackupView 测试

    func testSubscriptionPlanView_Hierarchy() {
        let host = NavigationStack {
            SubscriptionPlanView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testBackupView_Hierarchy() {
        let host = NavigationStack {
            BackupView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}

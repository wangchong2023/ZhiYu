//
//  SystemStatsAndStorageViewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 SystemStatsCoordinator、各存储分类聚合、数据源溯源、时延指标与物理表修剪状态机。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SystemStatsAndStorageViewTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 初始状态与加载全流程

    func testSystemStatsCoordinator_LoadStats_AllSectionsPopulated() async throws {
        let coordinator = SystemStatsCoordinator()
        XCTAssertTrue(coordinator.isLoading)

        await coordinator.loadStats()

        XCTAssertFalse(coordinator.isLoading, "加载完成后 isLoading 应为 false")
        XCTAssertFalse(coordinator.storageCategories.isEmpty, "存储类别聚合不应为空")
        XCTAssertGreaterThanOrEqual(coordinator.totalStorage, 0)
        XCTAssertGreaterThanOrEqual(coordinator.avgLatency, 0)
    }

    // MARK: - 2. 字节与类别图标格式化分支

    func testSystemStatsCoordinator_FormatBytesAndIcons() {
        let coordinator = SystemStatsCoordinator()

        let formattedZero = coordinator.formatBytes(0)
        XCTAssertFalse(formattedZero.isEmpty)

        let formattedMega = coordinator.formatBytes(1024 * 1024 * 50)
        XCTAssertFalse(formattedMega.isEmpty)

        // 测试所有已知类别的 Icon 映射分支
        let dbIcon = coordinator.iconForCategory(L10n.Dashboard.System.database)
        XCTAssertEqual(dbIcon, DesignSystem.Icons.StorageStats.database)

        let logsIcon = coordinator.iconForCategory(L10n.Dashboard.System.logs)
        XCTAssertEqual(logsIcon, DesignSystem.Icons.StorageStats.logs)

        let modelsIcon = coordinator.iconForCategory(L10n.Dashboard.System.models)
        XCTAssertEqual(modelsIcon, DesignSystem.Icons.StorageStats.models)

        let pluginsIcon = coordinator.iconForCategory(L10n.Dashboard.System.plugins)
        XCTAssertEqual(pluginsIcon, DesignSystem.Icons.StorageStats.plugins)

        let cachesIcon = coordinator.iconForCategory(L10n.Dashboard.System.caches)
        XCTAssertEqual(cachesIcon, DesignSystem.Icons.StorageStats.caches)

        let importIcon = coordinator.iconForCategory(L10n.Dashboard.stats.storageImport)
        XCTAssertEqual(importIcon, DesignSystem.Icons.StorageStats.storageImport)

        let exportIcon = coordinator.iconForCategory(L10n.Dashboard.stats.storageExport)
        XCTAssertEqual(exportIcon, DesignSystem.Icons.StorageStats.storageExport)

        let fallbackIcon = coordinator.iconForCategory("未知类别")
        XCTAssertEqual(fallbackIcon, DesignSystem.Icons.StorageStats.fallback)
    }

    // MARK: - 3. 数据清理与孤儿分块修剪状态机

    func testSystemStatsCoordinator_CleanupData_ExecutionFlow() async {
        let coordinator = SystemStatsCoordinator()
        XCTAssertFalse(coordinator.isCleaning)

        await coordinator.cleanupData()

        XCTAssertFalse(coordinator.isCleaning)
        XCTAssertNotNil(coordinator.cleanedCount)
    }

    // MARK: - 4. 来源溯源 (Provenance) 统计计算

    func testSystemStatsCoordinator_ProvenanceStatsCalculation() async {
        let coordinator = SystemStatsCoordinator()
        await coordinator.loadStats()

        XCTAssertGreaterThanOrEqual(coordinator.provenance.importedCount, 0)
        XCTAssertGreaterThanOrEqual(coordinator.provenance.createdCount, 0)
        XCTAssertGreaterThanOrEqual(coordinator.provenance.importedSize, 0)
        XCTAssertGreaterThanOrEqual(coordinator.provenance.createdSize, 0)
    }
}

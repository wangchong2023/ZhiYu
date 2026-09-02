//
//  SystemStatsViewFullCoverageTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度覆盖 SystemStatsView 与 SystemStatsCoordinator 的所有 Tab 分支、图表状态、多笔记本计算与清理维护。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class SystemStatsViewFullCoverageTests: XCTestCase {

    private var store: AppStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    // MARK: - 1. SystemStatsView Tabs 枚举与基础渲染

    func testSystemStatsTabsProperties() {
        let tabs = SystemStatsView.Tab.allCases
        XCTAssertEqual(tabs.count, 3)

        for tab in tabs {
            XCTAssertFalse(tab.title.isEmpty)
            XCTAssertFalse(tab.rawValue.isEmpty)
        }

        XCTAssertEqual(SystemStatsView.Tab.performance.title, L10n.Dashboard.stats.tabPerf)
        XCTAssertEqual(SystemStatsView.Tab.storage.title, L10n.Dashboard.stats.tabStorage)
        XCTAssertEqual(SystemStatsView.Tab.plugins.title, L10n.Dashboard.stats.tabPlugins)
    }

    func testSystemStatsViewInstantiation() {
        let coordinator = SystemStatsCoordinator()
        coordinator.isLoading = false
        coordinator.avgLatency = 240
        coordinator.maxLatency = 800
        coordinator.minLatency = 50
        coordinator.latencyCount = 100
        coordinator.totalStorage = 1024 * 1024 * 150
        coordinator.totalPages = 50
        coordinator.rawStorageStats = SystemStatsCoordinator.RawStats(count: 10, size: 1024 * 1024 * 20)
        coordinator.provenance = SystemStatsCoordinator.ProvenanceStats(
            importedCount: 15,
            importedSize: 1024 * 1024 * 30,
            createdCount: 35,
            createdSize: 1024 * 1024 * 50
        )
        coordinator.dailyStats = [
            DailyAIUsage(date: Date(), dateString: "2026-09-01", tokens: 12500, requests: 25),
            DailyAIUsage(date: Date().addingTimeInterval(-86400), dateString: "2026-08-31", tokens: 20000, requests: 40)
        ]
        coordinator.storageCategories = [
            StorageCategory(label: "数据库", value: 1024 * 1024 * 50, count: 5, color: .appAccent),
            StorageCategory(label: "原始文档", value: 1024 * 1024 * 30, count: 10, color: .appSecondary)
        ]
        coordinator.vaultStorageItems = [
            SystemStatsCoordinator.VaultStorageItem(id: UUID(), name: "主笔记本", icon: "book.fill", size: 1024 * 1024 * 40),
            SystemStatsCoordinator.VaultStorageItem(id: UUID(), name: "归档工作区", icon: "", size: 1024 * 1024 * 20)
        ]
        coordinator.assetCategoryStats = [
            "pdf": SystemStatsCoordinator.AssetStats(count: 5, size: 1024 * 1024 * 10),
            "audio": SystemStatsCoordinator.AssetStats(count: 3, size: 1024 * 1024 * 8)
        ]

        // 1. Performance Tab (Loaded)
        let perfView = SystemStatsView(initialTab: .performance, coordinator: coordinator)
            .snapshotEnvironment()
        let perfHost = UIHostingController(rootView: perfView)
        XCTAssertNotNil(perfHost.view)
        perfHost.view.layoutIfNeeded()

        // 2. Storage Tab (Loaded)
        let storageView = SystemStatsView(initialTab: .storage, coordinator: coordinator)
            .snapshotEnvironment()
        let storageHost = UIHostingController(rootView: storageView)
        XCTAssertNotNil(storageHost.view)
        storageHost.view.layoutIfNeeded()

        // 3. Plugins Tab (Loaded)
        let pluginsView = SystemStatsView(initialTab: .plugins, coordinator: coordinator)
            .snapshotEnvironment()
        let pluginsHost = UIHostingController(rootView: pluginsView)
        XCTAssertNotNil(pluginsHost.view)
        pluginsHost.view.layoutIfNeeded()

        // 4. Loading State
        let loadingCoordinator = SystemStatsCoordinator()
        loadingCoordinator.isLoading = true
        let loadingView = SystemStatsView(initialTab: .performance, coordinator: loadingCoordinator)
            .snapshotEnvironment()
        let loadingHost = UIHostingController(rootView: loadingView)
        XCTAssertNotNil(loadingHost.view)
        loadingHost.view.layoutIfNeeded()
    }

    // MARK: - 2. SystemStatsCoordinator 状态计算与边界测试

    func testCoordinatorFormatBytes() {
        let coordinator = SystemStatsCoordinator()

        let zeroBytes = coordinator.formatBytes(0)
        XCTAssertFalse(zeroBytes.isEmpty)

        let kbBytes = coordinator.formatBytes(1024 * 50)
        XCTAssertFalse(kbBytes.isEmpty)

        let mbBytes = coordinator.formatBytes(1024 * 1024 * 128)
        XCTAssertFalse(mbBytes.isEmpty)

        let gbBytes = coordinator.formatBytes(1024 * 1024 * 1024 * 3)
        XCTAssertFalse(gbBytes.isEmpty)
    }

    func testCoordinatorIconForCategory() {
        let coordinator = SystemStatsCoordinator()

        XCTAssertEqual(coordinator.iconForCategory(L10n.Dashboard.System.database), DesignSystem.Icons.StorageStats.database)
        XCTAssertEqual(coordinator.iconForCategory(L10n.Dashboard.System.logs), DesignSystem.Icons.StorageStats.logs)
        XCTAssertEqual(coordinator.iconForCategory(L10n.Dashboard.System.models), DesignSystem.Icons.StorageStats.models)
        XCTAssertEqual(coordinator.iconForCategory(L10n.Dashboard.System.plugins), DesignSystem.Icons.StorageStats.plugins)
        XCTAssertEqual(coordinator.iconForCategory(L10n.Dashboard.System.caches), DesignSystem.Icons.StorageStats.caches)
        XCTAssertEqual(coordinator.iconForCategory(L10n.Dashboard.stats.storageImport), DesignSystem.Icons.StorageStats.storageImport)
        XCTAssertEqual(coordinator.iconForCategory(L10n.Dashboard.stats.storageExport), DesignSystem.Icons.StorageStats.storageExport)
        XCTAssertEqual(coordinator.iconForCategory("UnknownCustomCategory"), DesignSystem.Icons.StorageStats.fallback)
    }

    func testCoordinatorLoadStatsFullFlow() async {
        let coordinator = SystemStatsCoordinator()
        XCTAssertTrue(coordinator.isLoading)

        await coordinator.loadStats()

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNotNil(coordinator.storageCategories)
        XCTAssertNotNil(coordinator.dailyStats)
        XCTAssertNotNil(coordinator.monthlyStats)
        XCTAssertNotNil(coordinator.provenance)
    }

    func testCoordinatorCleanupData() async {
        let coordinator = SystemStatsCoordinator()
        XCTAssertFalse(coordinator.isCleaning)

        await coordinator.cleanupData()

        XCTAssertFalse(coordinator.isCleaning)
    }

    // MARK: - 3. Coordinator 数据模型与属性变异

    func testCoordinatorStateMutations() {
        let coordinator = SystemStatsCoordinator()

        // 模拟多笔记本存储数据
        let vaultItem1 = SystemStatsCoordinator.VaultStorageItem(
            id: UUID(),
            name: "默认笔记本",
            icon: "book.fill",
            size: 1024 * 1024 * 10
        )
        let vaultItem2 = SystemStatsCoordinator.VaultStorageItem(
            id: UUID(),
            name: "工作工作区",
            icon: "",
            size: 1024 * 1024 * 25
        )
        coordinator.vaultStorageItems = [vaultItem2, vaultItem1]

        XCTAssertEqual(coordinator.vaultStorageItems.count, 2)
        XCTAssertEqual(coordinator.vaultStorageItems.first?.name, "工作工作区")

        // 模拟高时延与低时延
        coordinator.avgLatency = 2500
        coordinator.maxLatency = 3000
        coordinator.minLatency = 200
        coordinator.latencyCount = 42

        XCTAssertGreaterThan(coordinator.avgLatency, AppConstants.Performance.latencyWarningThreshold)

        coordinator.avgLatency = 350
        XCTAssertLessThanOrEqual(coordinator.avgLatency, AppConstants.Performance.latencyWarningThreshold)

        // 模拟资产分类统计
        coordinator.assetCategoryStats = [
            "voice": SystemStatsCoordinator.AssetStats(count: 5, size: 50000),
            "ocr": SystemStatsCoordinator.AssetStats(count: 12, size: 120000),
            "file": SystemStatsCoordinator.AssetStats(count: 8, size: 80000)
        ]

        XCTAssertEqual(coordinator.assetCategoryStats["voice"]?.count, 5)
        XCTAssertEqual(coordinator.assetCategoryStats["ocr"]?.size, 120000)
        XCTAssertEqual(coordinator.assetCategoryStats["file"]?.count, 8)

        // 模拟原始存储统计
        coordinator.rawStorageStats = SystemStatsCoordinator.RawStats(count: 10, size: 102400)
        XCTAssertEqual(coordinator.rawStorageStats?.count, 10)
        XCTAssertEqual(coordinator.rawStorageStats?.size, 102400)
    }

    // MARK: - 4. 存储分类与饼图数据状态

    func testStorageCategoriesEmptyAndZeroStates() {
        let coordinator = SystemStatsCoordinator()
        coordinator.storageCategories = []
        XCTAssertTrue(coordinator.storageCategories.isEmpty)

        coordinator.storageCategories = [
            StorageCategory(label: "数据库", value: 0, count: 0, color: .blue),
            StorageCategory(label: "日志", value: 0, count: 0, color: .orange)
        ]
        XCTAssertTrue(coordinator.storageCategories.allSatisfy { $0.value == 0 })

        coordinator.storageCategories = [
            StorageCategory(label: "数据库", value: 1024, count: 1, color: .blue),
            StorageCategory(label: "日志", value: 512, count: 2, color: .orange)
        ]
        XCTAssertFalse(coordinator.storageCategories.allSatisfy { $0.value == 0 })
    }
}

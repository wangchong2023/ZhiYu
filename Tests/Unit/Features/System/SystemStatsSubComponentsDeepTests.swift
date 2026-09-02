//
//  SystemStatsSubComponentsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度覆盖 SystemStatsView 的图表渲染、各个卡片子组件与变异阈值分支。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class SystemStatsSubComponentsDeepTests: XCTestCase {

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

    // MARK: - 1. ChartView 渲染 (Requests & Tokens)

    func testChartViewEmptyAndLoaded() {
        let themeManager = ThemeManager()

        // 1. 空数据图表
        let emptyReqChart = ChartView(stats: [], type: .requests)
            .environment(themeManager)
            .snapshotEnvironment()
        let emptyHost = UIHostingController(rootView: emptyReqChart)
        _ = emptyHost.view

        let emptyTokenChart = ChartView(stats: [], type: .tokens)
            .environment(themeManager)
            .snapshotEnvironment()
        let emptyTokenHost = UIHostingController(rootView: emptyTokenChart)
        _ = emptyTokenHost.view

        // 2. 有数据图表 (Requests)
        let stats: [DailyAIUsage] = [
            DailyAIUsage(date: Date(), dateString: "2026-09-01", tokens: 15000, requests: 30),
            DailyAIUsage(date: Date().addingTimeInterval(-86400), dateString: "2026-08-31", tokens: 25000, requests: 60)
        ]
        let loadedReqChart = ChartView(stats: stats, type: .requests)
            .environment(themeManager)
            .snapshotEnvironment()
        let loadedHost = UIHostingController(rootView: loadedReqChart)
        _ = loadedHost.view

        // 3. 有数据图表 (Tokens)
        let loadedTokenChart = ChartView(stats: stats, type: .tokens)
            .environment(themeManager)
            .snapshotEnvironment()
        let loadedTokenHost = UIHostingController(rootView: loadedTokenChart)
        _ = loadedTokenHost.view
    }

    // MARK: - 2. SystemStatsView 全生命周期真实 Window 挂载渲染

    func testSystemStatsViewWindowMountRendering() {
        let coordinator = SystemStatsCoordinator()
        coordinator.isLoading = false
        coordinator.avgLatency = 120
        coordinator.maxLatency = 500
        coordinator.minLatency = 40
        coordinator.latencyCount = 50
        coordinator.totalStorage = 1024 * 1024 * 300
        coordinator.totalPages = 80
        coordinator.rawStorageStats = SystemStatsCoordinator.RawStats(count: 12, size: 1024 * 1024 * 25)
        coordinator.provenance = SystemStatsCoordinator.ProvenanceStats(
            importedCount: 20,
            importedSize: 1024 * 1024 * 50,
            createdCount: 60,
            createdSize: 1024 * 1024 * 100
        )
        coordinator.dailyStats = [
            DailyAIUsage(date: Date(), dateString: "2026-09-01", tokens: 10000, requests: 20),
            DailyAIUsage(date: Date().addingTimeInterval(-86400), dateString: "2026-08-31", tokens: 30000, requests: 70)
        ]
        coordinator.storageCategories = [
            StorageCategory(label: L10n.Dashboard.System.database, value: 1024 * 1024 * 60, count: 6, color: .appAccent),
            StorageCategory(label: L10n.Dashboard.stats.storageImport, value: 1024 * 1024 * 40, count: 12, color: .appSecondary),
            StorageCategory(label: "缓存数据", value: 1024 * 1024 * 20, count: 3, color: Color.theme.yellow)
        ]
        coordinator.vaultStorageItems = [
            SystemStatsCoordinator.VaultStorageItem(id: UUID(), name: "主知识库", icon: "book.fill", size: 1024 * 1024 * 50),
            SystemStatsCoordinator.VaultStorageItem(id: UUID(), name: "研究工作区", icon: "archivebox", size: 1024 * 1024 * 30)
        ]
        coordinator.assetCategoryStats = [
            "voice": SystemStatsCoordinator.AssetStats(count: 4, size: 1024 * 1024 * 15),
            "ocr": SystemStatsCoordinator.AssetStats(count: 8, size: 1024 * 1024 * 20),
            "file": SystemStatsCoordinator.AssetStats(count: 2, size: 1024 * 1024 * 5)
        ]

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))

        // 1. Performance Tab Mounted
        let perfView = SystemStatsView(initialTab: .performance, coordinator: coordinator)
            .snapshotEnvironment()
        let perfHost = UIHostingController(rootView: perfView)
        window.rootViewController = perfHost
        window.makeKeyAndVisible()
        perfHost.view.layoutIfNeeded()

        // 2. Storage Tab Mounted
        let storageView = SystemStatsView(initialTab: .storage, coordinator: coordinator)
            .snapshotEnvironment()
        let storageHost = UIHostingController(rootView: storageView)
        window.rootViewController = storageHost
        storageHost.view.layoutIfNeeded()

        // 3. Storage Tab with All-Zero Categories (Empty State)
        coordinator.storageCategories = [
            StorageCategory(label: "空类别", value: 0, count: 0, color: .appAccent)
        ]
        let emptyStorageView = SystemStatsView(initialTab: .storage, coordinator: coordinator)
            .snapshotEnvironment()
        let emptyHost = UIHostingController(rootView: emptyStorageView)
        window.rootViewController = emptyHost
        emptyHost.view.layoutIfNeeded()

        // 4. Loading State
        coordinator.isLoading = true
        let loadingView = SystemStatsView(initialTab: .performance, coordinator: coordinator)
            .snapshotEnvironment()
        let loadingHost = UIHostingController(rootView: loadingView)
        window.rootViewController = loadingHost
        loadingHost.view.layoutIfNeeded()
    }

    // MARK: - 3. PluginStatsSection 视图覆盖

    func testPluginStatsSectionRendering() {
        let section = PluginStatsSection()
            .snapshotEnvironment()
        let host = UIHostingController(rootView: section)
        _ = host.view
        host.view.layoutIfNeeded()
    }
}

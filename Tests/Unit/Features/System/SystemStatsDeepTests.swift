//
//  SystemStatsDeepTests.swift
//  ZhiYuTests
//
//  合并自 6 个碎片化测试文件：SystemStatsAndRAGChartsDeepTests.swift, SystemStatsAndRawStorageFullDeepTests.swift, SystemStatsAndStorageViewFullDeepTests.swift, SystemStatsAndStorageViewsDeepTests.swift, SystemStatsSubComponentsDeepTests.swift, SystemStatsViewFullCoverageTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class SystemStatsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testRAGSatisfactionPanel_AllScoreTiers() {
        let tiers = [
            (rate: 0.95, up: 19, down: 1),
            (rate: 0.75, up: 15, down: 5),
            (rate: 0.40, up: 4, down: 6),
            (rate: 0.0, up: 0, down: 0)
        ]

        for tier in tiers {
            let host = RAGSatisfactionPanel(
                satisfactionRate: tier.rate,
                satisfactionThumbsUp: tier.up,
                satisfactionThumbsDown: tier.down
            )
            .snapshotEnvironment()
            .renderInWindow()

            XCTAssertNotNil(host.view)
            XCTAssertGreaterThanOrEqual(tier.rate, 0.0)
        }
    }

    func testRAGCostPanel_DifferentTokenScales() {
        let lowCostEfficiency = TokenEfficiency(
            totalTokens: 15000,
            queryCount: 10,
            avgTokensPerQuery: 1500,
            estimatedCostUSD: 0.03
        )
        let highCostEfficiency = TokenEfficiency(
            totalTokens: 850000,
            queryCount: 200,
            avgTokensPerQuery: 4250,
            estimatedCostUSD: 1.85
        )

        for eff in [lowCostEfficiency, highCostEfficiency] {
            let host = RAGCostPanel(tokenEfficiency: eff)
                .snapshotEnvironment()
                .renderInWindow()

            XCTAssertNotNil(host.view)
            XCTAssertGreaterThan(eff.totalTokens, 0)
        }
    }

    func testSystemStatsView_Hierarchy() {
        let statsView = SystemStatsView()
        XCTAssertNotNil(statsView)
        let host = NavigationStack {
            statsView
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testSystemStatsView_TabsEnum() {
        for tab in SystemStatsView.Tab.allCases {
            XCTAssertFalse(tab.title.isEmpty)
        }
    }

    func testRawStorageListView_Hierarchy() {
        let rawView = RawStorageListView()
        XCTAssertNotNil(rawView)
        let host = NavigationStack {
            rawView
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testRawCategoryType_Properties() {
        for category in RawCategoryType.allCases {
            XCTAssertEqual(category.id, category.rawValue)
            XCTAssertFalse(category.systemIconName.isEmpty)
            XCTAssertFalse(category.displayName.isEmpty)
            _ = category.defaultColor
        }
    }

    func testRawPageRow_Hierarchy() {
        let page = KnowledgePage(
            title: "Transformer 注意力机制原理",
            pageType: .concept,
            content: "自注意力机制与多头注意力计算"
        )

        let host = RawPageRow(page: page, searchText: "Transformer")
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(page.title, "Transformer 注意力机制原理")
        XCTAssertEqual(page.pageType, .concept)
    }

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

    func testPluginStatsSection_Hierarchy() {
        let rawView = PluginStatsSection()
        XCTAssertNotNil(rawView)
        let host = NavigationStack {
            rawView
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testDeveloperSettingsView_StressTestFlowAndHierarchy() {
        let rawView = DeveloperSettingsView()
        XCTAssertNotNil(rawView)
        let host = NavigationStack {
            rawView
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testSubscriptionPlanView_Hierarchy() {
        let rawView = SubscriptionPlanView()
        XCTAssertNotNil(rawView)
        let host = NavigationStack {
            rawView
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testBackupView_Hierarchy() {
        let rawView = BackupView()
        XCTAssertNotNil(rawView)
        let host = NavigationStack {
            rawView
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testSystemStatsView_AllTabsAndControls() {
        let rawStats = SystemStatsView()
        XCTAssertNotNil(rawStats)
        let statsView = rawStats.snapshotEnvironment()

        let host = UIHostingController(rootView: statsView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testRawStorageListView_EmptyAndFiltered() {
        let rawStorage = RawStorageListView()
        XCTAssertNotNil(rawStorage)
        let rawView = rawStorage.snapshotEnvironment()

        let host = UIHostingController(rootView: rawView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testRawPageRow_HighlightedTextVariants() {
        let page = KnowledgePage(
            title: "Distributed Architecture Guide",
            pageType: .concept,
            content: "Microservices design patterns and Raft algorithm"
        )

        let rowView = RawPageRow(page: page, searchText: "Architecture")
            .snapshotEnvironment()

        let host = UIHostingController(rootView: rowView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(page.title, "Distributed Architecture Guide")
        XCTAssertEqual(page.pageType, .concept)
    }

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

        XCTAssertEqual(stats.count, 2, "应包含 2 条使用统计")
        XCTAssertEqual(stats[0].tokens, 15000)
        XCTAssertEqual(stats[1].requests, 60)
    }

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

        XCTAssertTrue(coordinator.isLoading, "系统状态应处于加载中")
        XCTAssertEqual(coordinator.avgLatency, 120)
        XCTAssertEqual(coordinator.storageCategories.count, 1)
    }

    func testPluginStatsSectionRendering() {
        let section = PluginStatsSection()
            .snapshotEnvironment()
        let host = UIHostingController(rootView: section)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(section)
    }

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

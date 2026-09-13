//
//  SystemStatsCoordinatorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 SystemStatsCoordinator 的字节格式化、图标选择与统计加载流程。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class SystemStatsCoordinatorTests: XCTestCase {

    private var coordinator: SystemStatsCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        coordinator = SystemStatsCoordinator()
    }

    override func tearDown() async throws {
        coordinator = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - formatBytes

    /// 验证 formatBytes(0) 返回 "Zero bytes"
    func testFormatBytesZero() {
        let result = coordinator.formatBytes(0)
        // ByteCountFormatter 对 0 返回 "Zero bytes" 或 "0 bytes"
        XCTAssertTrue(result.contains("0") || result.lowercased().contains("zero"),
                      "0 字节应包含 0 或 zero")
    }

    /// 验证 formatBytes(1024) 返回 KB 级别
    func testFormatBytesKB() {
        let result = coordinator.formatBytes(1024)
        XCTAssertTrue(result.contains("KB") || result.contains("kB"),
                      "1024 字节应格式化为 KB")
    }

    /// 验证 formatBytes(1048576) 返回 MB 级别
    func testFormatBytesMB() {
        let result = coordinator.formatBytes(1048576)
        XCTAssertTrue(result.contains("MB"), "1048576 字节应格式化为 MB")
    }

    /// 验证 formatBytes 负数不崩溃
    func testFormatBytesNegativeNoCrash() {
        let result = coordinator.formatBytes(-100)
        // 负数应返回某种格式化字符串，不崩溃
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - iconForCategory

    /// 验证 iconForCategory 数据库标签返回 database 图标
    func testIconForCategoryDatabase() {
        let result = coordinator.iconForCategory(L10n.Dashboard.System.database)
        XCTAssertEqual(result, DesignSystem.Icons.StorageStats.database)
    }

    /// 验证 iconForCategory 日志标签返回 logs 图标
    func testIconForCategoryLogs() {
        let result = coordinator.iconForCategory(L10n.Dashboard.System.logs)
        XCTAssertEqual(result, DesignSystem.Icons.StorageStats.logs)
    }

    /// 验证 iconForCategory 导入标签返回 storageImport 图标
    func testIconForCategoryImport() {
        let result = coordinator.iconForCategory(L10n.Dashboard.stats.storageImport)
        XCTAssertEqual(result, DesignSystem.Icons.StorageStats.storageImport)
    }

    /// 验证 iconForCategory 导出标签返回 storageExport 图标
    func testIconForCategoryExport() {
        let result = coordinator.iconForCategory(L10n.Dashboard.stats.storageExport)
        XCTAssertEqual(result, DesignSystem.Icons.StorageStats.storageExport)
    }

    /// 验证 iconForCategory 未知标签返回 fallback 图标
    func testIconForCategoryUnknownReturnsFallback() {
        let result = coordinator.iconForCategory("未知分类")
        XCTAssertEqual(result, DesignSystem.Icons.StorageStats.fallback)
    }

    // MARK: - loadStats

    /// 验证 loadStats 后 isLoading 变为 false
    func testLoadStatsSetsIsLoadingFalse() async {
        await coordinator.loadStats()
        XCTAssertFalse(coordinator.isLoading, "loadStats 完成后 isLoading 应为 false")
    }

    /// 验证 loadStats 后 totalPages 非负
    func testLoadStatsTotalPagesNonNegative() async {
        await coordinator.loadStats()
        XCTAssertGreaterThanOrEqual(coordinator.totalPages, 0,
                                    "totalPages 应为非负数")
    }

    /// 验证 loadStats 后 storageCategories 非空
    func testLoadStatsStorageCategoriesNotEmpty() async {
        await coordinator.loadStats()
        XCTAssertFalse(coordinator.storageCategories.isEmpty,
                       "loadStats 后应填充 storageCategories")
    }

    /// 验证 loadStats 后 totalStorage 等于各分类之和
    func testLoadStatsTotalStorageEqualsSum() async {
        await coordinator.loadStats()
        let sum = coordinator.storageCategories.reduce(Int64(0)) { $0 + $1.value }
        XCTAssertEqual(coordinator.totalStorage, sum,
                       "totalStorage 应等于各分类 value 之和")
    }

    /// 验证 loadStats 后 dailyStats 非空（至少填充当月天数）
    func testLoadStatsDailyStatsNotEmpty() async {
        await coordinator.loadStats()
        XCTAssertFalse(coordinator.dailyStats.isEmpty,
                       "dailyStats 应填充当月每日条目")
    }

    /// 验证 loadStats 后 rawStorageStats 被设置（即使为 0）
    func testLoadStatsRawStorageStatsSet() async {
        await coordinator.loadStats()
        XCTAssertNotNil(coordinator.rawStorageStats,
                        "rawStorageStats 应被设置")
    }

    // MARK: - 初始状态

    /// 验证初始 isLoading 为 true
    func testInitialIsLoadingTrue() {
        // 新建 coordinator 初始 isLoading 应为 true
        let fresh = SystemStatsCoordinator()
        XCTAssertTrue(fresh.isLoading, "新建 coordinator isLoading 应为 true")
    }

    /// 验证初始 totalStorage 为 0
    func testInitialTotalStorageZero() {
        let fresh = SystemStatsCoordinator()
        XCTAssertEqual(fresh.totalStorage, 0)
    }
}

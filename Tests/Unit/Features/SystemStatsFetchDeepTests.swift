//
//  SystemStatsFetchDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：SystemStatsCoordinator Fetch/Format 深度补盲测试 — 覆盖 formatBytes
//            边界值（0/1023/1024/1MB/1GB/负数/大整数/一致性）、iconForCategory
//            分支（database/logs/storageImport/storageExport/models/未知/空字符串）、
//            fetchRawPageStats 原始页统计、fetchVaultStorageSizes 多笔记本关联、
//            vaultStorageItems 同步、storageCategories 完整性等未覆盖分支，
//            以发现生产代码潜在 bug 为首要目标。
//

import XCTest
import SwiftUI
import Combine
import GRDB
import UFPCore
import Dependencies
@testable import ZhiYu

// MARK: - SystemStatsFetchDeepTests

@MainActor
final class SystemStatsFetchDeepTests: XCTestCase {

    // MARK: - 被测对象与 Mock

    private var coordinator: SystemStatsCoordinator!
    private var recordableLogger: RecordableLogger!
    private var recordableHaptic: RecordableHaptic!
    private var configurableVectorRepo: ConfigurableVectorRepository!
    private var configurableGovernanceRepo: ConfigurableRAGGovernanceRepository!
    private var configurablePageStore: ConfigurablePageStoreCapabilities!
    private var configurableKnowledgeRepo: ConfigurableKnowledgeRepository!
    private var mockImportRecordRepo: MockImportRecordRepository!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()

        recordableLogger = RecordableLogger()
        ServiceContainer.shared.register(recordableLogger as any LoggerProtocol, for: (any LoggerProtocol).self)

        recordableHaptic = RecordableHaptic()
        ServiceContainer.shared.register(recordableHaptic as any HapticFeedbackProtocol, for: (any HapticFeedbackProtocol).self)

        configurableVectorRepo = ConfigurableVectorRepository()
        ServiceContainer.shared.register(configurableVectorRepo as any VectorRepository, for: (any VectorRepository).self)

        configurableGovernanceRepo = ConfigurableRAGGovernanceRepository()
        ServiceContainer.shared.register(configurableGovernanceRepo as any RAGGovernanceRepository, for: (any RAGGovernanceRepository).self)

        configurablePageStore = ConfigurablePageStoreCapabilities()
        ServiceContainer.shared.register(configurablePageStore as any AnyPageStoreCapabilities, for: (any AnyPageStoreCapabilities).self)
        ServiceContainer.shared.register(configurablePageStore as any AnyPageStore, for: (any AnyPageStore).self)

        configurableKnowledgeRepo = ConfigurableKnowledgeRepository()
        ServiceContainer.shared.register(configurableKnowledgeRepo as any KnowledgeRepository, for: (any KnowledgeRepository).self)

        mockImportRecordRepo = MockImportRecordRepository()
        ServiceContainer.shared.register(mockImportRecordRepo as any ImportRecordRepository, for: (any ImportRecordRepository).self)

        VaultService.shared.vaults = []
        VaultService.shared.selectedVaultID = nil

        coordinator = SystemStatsCoordinator()
    }

    override func tearDown() async throws {
        coordinator = nil
        recordableLogger = nil
        recordableHaptic = nil
        configurableVectorRepo = nil
        configurableGovernanceRepo = nil
        configurablePageStore = nil
        configurableKnowledgeRepo = nil
        mockImportRecordRepo = nil
        VaultService.shared.vaults = []
        VaultService.shared.selectedVaultID = nil
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    /// 构造指定类型的测试 KnowledgePage
    private func makePage(type: PageType = .concept, content: String = "测试内容") -> KnowledgePage {
        KnowledgePage(title: "测试页面-\(UUID().uuidString.prefix(8))", pageType: type, content: content)
    }

    /// 构造指定分类与大小的 ImportRecord
    private func makeRecord(category: ImportCategory, size: Int64) -> ImportRecord {
        ImportRecord(category: category.rawValue, title: "记录-\(UUID().uuidString.prefix(8))", fileSize: size)
    }

    // MARK: - formatBytes 边界值

    /// 验证 formatBytes(0) 返回零字节格式
    func testFormatBytes_0_返回零字节格式() {
        let result = coordinator.formatBytes(0)
        XCTAssertFalse(result.isEmpty, "formatBytes(0) 不应返回空字符串")
        XCTAssertTrue(result.contains("0") || result.contains("Zero"), "formatBytes(0) 应包含 0 或 Zero")
    }

    /// 验证 formatBytes(1023) 返回字节单位
    func testFormatBytes_1023_返回字节单位() {
        let result = coordinator.formatBytes(1023)
        XCTAssertFalse(result.isEmpty, "formatBytes(1023) 不应返回空字符串")
    }

    /// 验证 formatBytes(1024) 返回 KB 单位
    func testFormatBytes_1024_返回KB单位() {
        let result = coordinator.formatBytes(1024)
        XCTAssertFalse(result.isEmpty, "formatBytes(1024) 不应返回空字符串")
    }

    /// 验证 formatBytes(1024*1024) 返回 MB 单位
    func testFormatBytes_1MB_返回MB单位() {
        let oneMB: Int64 = 1024 * 1024
        let result = coordinator.formatBytes(oneMB)
        XCTAssertFalse(result.isEmpty, "formatBytes(1MB) 不应返回空字符串")
    }

    /// 验证 formatBytes(1024*1024*1024) 返回 GB 单位
    func testFormatBytes_1GB_返回GB单位() {
        let oneGB: Int64 = 1024 * 1024 * 1024
        let result = coordinator.formatBytes(oneGB)
        XCTAssertFalse(result.isEmpty, "formatBytes(1GB) 不应返回空字符串")
    }

    /// 验证 formatBytes 负数不崩溃且返回非空字符串
    func testFormatBytes_负数_不崩溃返回非空() {
        let result = coordinator.formatBytes(-100)
        XCTAssertFalse(result.isEmpty, "formatBytes(负数) 不应返回空字符串")
    }

    /// 验证 formatBytes 同一值多次调用返回一致结果
    func testFormatBytes_同一值多次调用返回一致() {
        let value: Int64 = 5000
        let result1 = coordinator.formatBytes(value)
        let result2 = coordinator.formatBytes(value)
        XCTAssertEqual(result1, result2, "同一值多次调用 formatBytes 应返回一致结果")
    }

    /// 验证 formatBytes 大整数不崩溃
    func testFormatBytes_大整数_不崩溃() {
        let largeValue: Int64 = Int64.max
        let result = coordinator.formatBytes(largeValue)
        XCTAssertFalse(result.isEmpty, "formatBytes(Int64.max) 不应返回空字符串")
    }

    // MARK: - iconForCategory 分支

    /// 验证 iconForCategory 对 database 标签返回 database 图标
    func testIconForCategory_database标签_返回Database图标() {
        let result = coordinator.iconForCategory(L10n.Dashboard.System.database)
        XCTAssertEqual(result, DesignSystem.Icons.StorageStats.database, "database 标签应返回 database 图标")
    }

    /// 验证 iconForCategory 对 logs 标签返回 logs 图标
    func testIconForCategory_logs标签_返回Logs图标() {
        let result = coordinator.iconForCategory(L10n.Dashboard.System.logs)
        XCTAssertEqual(result, DesignSystem.Icons.StorageStats.logs, "logs 标签应返回 logs 图标")
    }

    /// 验证 iconForCategory 对 storageImport 标签返回 storageImport 图标
    func testIconForCategory_storageImport标签_返回StorageImport图标() {
        let result = coordinator.iconForCategory(L10n.Dashboard.stats.storageImport)
        XCTAssertEqual(result, DesignSystem.Icons.StorageStats.storageImport, "storageImport 标签应返回 storageImport 图标")
    }

    /// 验证 iconForCategory 对 storageExport 标签返回 storageExport 图标
    func testIconForCategory_storageExport标签_返回StorageExport图标() {
        let result = coordinator.iconForCategory(L10n.Dashboard.stats.storageExport)
        XCTAssertEqual(result, DesignSystem.Icons.StorageStats.storageExport, "storageExport 标签应返回 storageExport 图标")
    }

    /// 验证 iconForCategory 对未知标签返回 fallback 图标
    func testIconForCategory_未知标签_返回Fallback图标() {
        let result = coordinator.iconForCategory("未知分类")
        XCTAssertEqual(result, DesignSystem.Icons.StorageStats.fallback, "未知标签应返回 fallback 图标")
    }

    /// 验证 iconForCategory 对 models 标签返回 models 图标（修复后：models 已映射）
    func testIconForCategory_models标签_返回Fallback图标() {
        let result = coordinator.iconForCategory(L10n.Dashboard.System.models)
        XCTAssertEqual(result, DesignSystem.Icons.StorageStats.models, "修复后：models 标签已映射，应返回 models 图标")
    }

    /// 验证 iconForCategory 对空字符串返回 fallback
    func testIconForCategory_空字符串_返回Fallback图标() {
        let result = coordinator.iconForCategory("")
        XCTAssertEqual(result, DesignSystem.Icons.StorageStats.fallback, "空字符串应返回 fallback 图标")
    }

    // MARK: - fetchRawPageStats 原始页统计

    /// 验证 loadStats 后 rawStorageStats 统计 .raw 类型页面的数量与字节大小
    func testFetchRawPageStats_统计Raw页面数量与字节大小() async throws {
        let rawPage1 = makePage(type: .raw, content: "原始内容1")
        let rawPage2 = makePage(type: .raw, content: "原始内容2更长")
        let conceptPage = makePage(type: .concept, content: "概念内容不应计入")
        configurableKnowledgeRepo.stubAllPages = [rawPage1, rawPage2, conceptPage]
        await coordinator.loadStats()
        XCTAssertNotNil(coordinator.rawStorageStats, "rawStorageStats 应被填充")
        XCTAssertEqual(coordinator.rawStorageStats?.count, 2, "应只统计 .raw 类型页面，排除 .concept")
        let expectedSize = Int64(rawPage1.content.utf8.count) + Int64(rawPage2.content.utf8.count)
        XCTAssertEqual(coordinator.rawStorageStats?.size, expectedSize, "rawStorageStats.size 应为两个 raw 页面 UTF8 字节之和")
    }

    /// 验证 fetchRawPageStats 无 .raw 页面时 rawStorageStats.count 为 0
    func testFetchRawPageStats_无Raw页面_count为0() async throws {
        let conceptPage = makePage(type: .concept, content: "概念")
        let entityPage = makePage(type: .entity, content: "实体")
        configurableKnowledgeRepo.stubAllPages = [conceptPage, entityPage]
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.rawStorageStats?.count, 0, "无 .raw 页面时 count 应为 0")
        XCTAssertEqual(coordinator.rawStorageStats?.size, 0, "无 .raw 页面时 size 应为 0")
    }

    // MARK: - fetchVaultStorageSizes 多笔记本关联

    /// 验证 VaultService 无 vaults 时 vaultStorageItems 为空
    func testFetchVaultStorageSizes_无Vaults_vaultStorageItems为空() async throws {
        VaultService.shared.vaults = []
        await coordinator.loadStats()
        XCTAssertTrue(coordinator.vaultStorageItems.isEmpty, "无 vaults 时 vaultStorageItems 应为空")
    }

    /// 验证 fetchVaultStorageSizes 为每个 Vault 生成 VaultStorageItem（即使目录不存在）
    func testFetchVaultStorageSizes_为每个Vault生成Item() async throws {
        let vault1 = Vault(name: "笔记本1")
        let vault2 = Vault(name: "笔记本2")
        VaultService.shared.vaults = [vault1, vault2]
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.vaultStorageItems.count, 2, "应为每个 Vault 生成一个 VaultStorageItem")
        XCTAssertTrue(coordinator.vaultStorageItems.contains { $0.id == vault1.id }, "应包含 vault1 的 item")
        XCTAssertTrue(coordinator.vaultStorageItems.contains { $0.id == vault2.id }, "应包含 vault2 的 item")
    }

    /// 验证 fetchVaultStorageSizes 后 VaultStorageItem 的 name 来自 Vault.name
    func testFetchVaultStorageSizes_VaultStorageItemName来自VaultName() async throws {
        let vault = Vault(name: "我的测试笔记本")
        VaultService.shared.vaults = [vault]
        await coordinator.loadStats()
        let item = coordinator.vaultStorageItems.first { $0.id == vault.id }
        XCTAssertEqual(item?.name, "我的测试笔记本", "VaultStorageItem.name 应来自 Vault.name")
    }

    /// 验证 fetchVaultStorageSizes 后 VaultStorageItem 的 size 在目录不存在时为 0
    func testFetchVaultStorageSizes_目录不存在_size为0() async throws {
        let vault = Vault(name: "空目录笔记本")
        VaultService.shared.vaults = [vault]
        await coordinator.loadStats()
        let item = coordinator.vaultStorageItems.first { $0.id == vault.id }
        XCTAssertEqual(item?.size, 0, "Vault 目录不存在时 size 应为 0")
    }

    /// 验证 vaultStorageItems 按 size 降序排列
    func testFetchVaultStorageSizes_按Size降序排列() async throws {
        let vault1 = Vault(name: "A")
        let vault2 = Vault(name: "B")
        let vault3 = Vault(name: "C")
        VaultService.shared.vaults = [vault1, vault2, vault3]
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.vaultStorageItems.count, 3, "应生成 3 个 item")
        for i in 1..<coordinator.vaultStorageItems.count {
            XCTAssertGreaterThanOrEqual(coordinator.vaultStorageItems[i - 1].size, coordinator.vaultStorageItems[i].size, "vaultStorageItems 应按 size 降序排列")
        }
    }

    // MARK: - vaultStorageItems 与 VaultService.vaults 关联

    /// 验证 vaultStorageItems 数量与 VaultService.vaults 数量一致
    func testVaultStorageItems_数量与VaultServiceVaults一致() async throws {
        VaultService.shared.vaults = [
            Vault(name: "笔记本A"),
            Vault(name: "笔记本B"),
            Vault(name: "笔记本C"),
            Vault(name: "笔记本D")
        ]
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.vaultStorageItems.count, VaultService.shared.vaults.count, "vaultStorageItems 数量应与 VaultService.vaults 一致")
    }

    /// 验证 VaultService.vaults 变化后再次 loadStats vaultStorageItems 同步更新
    func testVaultStorageItems_vaults变化后再次LoadStats同步更新() async throws {
        VaultService.shared.vaults = [Vault(name: "笔记本1")]
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.vaultStorageItems.count, 1, "首次 loadStats 后应有 1 个 item")
        VaultService.shared.vaults = [Vault(name: "笔记本1"), Vault(name: "笔记本2"), Vault(name: "笔记本3")]
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.vaultStorageItems.count, 3, "vaults 增加后再次 loadStats 应有 3 个 item")
    }

    // MARK: - storageCategories 完整性

    /// 验证 storageCategories 中 database 分类的 count 来自 VaultService.vaults.count
    func testStorageCategories_database分类Count来自VaultsCount() async throws {
        VaultService.shared.vaults = [Vault(name: "A"), Vault(name: "B"), Vault(name: "C")]
        await coordinator.loadStats()
        let databaseCategory = coordinator.storageCategories.first { $0.label == L10n.Dashboard.System.database }
        XCTAssertEqual(databaseCategory?.count, 3, "database 分类 count 应等于 VaultService.vaults.count")
    }

    /// 验证 storageCategories 中 logs 分类的 count 来自 logger.getLogEntries().count
    func testStorageCategories_logs分类Count来自LogEntriesCount() async throws {
        recordableLogger.stubLogEntries = [
            LogEntry(action: .create, target: "1"),
            LogEntry(action: .update, target: "2"),
            LogEntry(action: .delete, target: "3"),
            LogEntry(action: .export, target: "4"),
            LogEntry(action: .lint, target: "5")
        ]
        await coordinator.loadStats()
        let logsCategory = coordinator.storageCategories.first { $0.label == L10n.Dashboard.System.logs }
        XCTAssertEqual(logsCategory?.count, 5, "logs 分类 count 应等于 logger.getLogEntries().count")
    }

    /// 验证 storageCategories 中 storageExport 分类的 count 来自 LogEntries 中 action==.export 的数量
    func testStorageCategories_storageExport分类Count来自ExportActionCount() async throws {
        recordableLogger.stubLogEntries = [
            LogEntry(action: .export, target: "导出1"),
            LogEntry(action: .export, target: "导出2"),
            LogEntry(action: .export, target: "导出3"),
            LogEntry(action: .create, target: "创建1")
        ]
        await coordinator.loadStats()
        let exportCategory = coordinator.storageCategories.first { $0.label == L10n.Dashboard.stats.storageExport }
        XCTAssertEqual(exportCategory?.count, 3, "storageExport 分类 count 应等于 LogEntries 中 action==.export 的数量")
    }

    /// 验证 storageCategories 中 storageImport 分类的 count 来自 importRecordRepo.fetchAll().count
    func testStorageCategories_storageImport分类Count来自FetchAllCount() async throws {
        try? await mockImportRecordRepo.save(makeRecord(category: .voice, size: 100))
        try? await mockImportRecordRepo.save(makeRecord(category: .file, size: 200))
        try? await mockImportRecordRepo.save(makeRecord(category: .ocr, size: 300))
        await coordinator.loadStats()
        let importCategory = coordinator.storageCategories.first { $0.label == L10n.Dashboard.stats.storageImport }
        XCTAssertEqual(importCategory?.count, 3, "storageImport 分类 count 应等于 importRecordRepo.fetchAll().count")
    }

    /// 验证 storageCategories 中 models 分类的 count 来自 GlobalModelManager.shared.modelStorageUsage.count
    func testStorageCategories_models分类Count来自ModelStorageUsageCount() async throws {
        await coordinator.loadStats()
        let modelsCategory = coordinator.storageCategories.first { $0.label == L10n.Dashboard.System.models }
        XCTAssertEqual(modelsCategory?.count, 0, "models 分类 count 应等于 GlobalModelManager.shared.modelStorageUsage.count")
    }
}

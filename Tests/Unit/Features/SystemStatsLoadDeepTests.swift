//
//  SystemStatsLoadDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：SystemStatsCoordinator Load 深度补盲测试 — 覆盖 loadStats 正常/空/失败路径、
//            isLoading 状态机、多次 loadStats 幂等性、provenance 与延迟属性等
//            未覆盖分支，以发现生产代码潜在 bug 为首要目标。
//

import XCTest
import SwiftUI
import Combine
import GRDB
import UFPCore
import Dependencies
@testable import ZhiYu

// MARK: - SystemStatsLoadDeepTests

@MainActor
final class SystemStatsLoadDeepTests: XCTestCase {

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

    /// 构造指定分类与大小的 ImportRecord
    private func makeRecord(category: ImportCategory, size: Int64) -> ImportRecord {
        ImportRecord(category: category.rawValue, title: "记录-\(UUID().uuidString.prefix(8))", fileSize: size)
    }

    /// 构造今日日期字符串（yyyy-MM-dd）
    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = AppConstants.Keys.Stats.dailyDateFormat
        return formatter.string(from: Date())
    }

    // MARK: - 初始状态

    /// 验证 init 后所有状态属性为初始默认值
    func testInitAllStatePropsAreInitialDefaults() {
        XCTAssertTrue(coordinator.isLoading, "init 后 isLoading 应为 true（默认加载中）")
        XCTAssertFalse(coordinator.isCleaning, "init 后 isCleaning 应为 false")
        XCTAssertNil(coordinator.cleanedCount, "init 后 cleanedCount 应为 nil")
        XCTAssertTrue(coordinator.dailyStats.isEmpty, "init 后 dailyStats 应为空")
        XCTAssertTrue(coordinator.monthlyStats.isEmpty, "init 后 monthlyStats 应为空")
        XCTAssertEqual(coordinator.totalStorage, 0, "init 后 totalStorage 应为 0")
        XCTAssertEqual(coordinator.exportCount, 0, "init 后 exportCount 应为 0")
        XCTAssertEqual(coordinator.exportSize, 0, "init 后 exportSize 应为 0")
        XCTAssertEqual(coordinator.totalPages, 0, "init 后 totalPages 应为 0")
        XCTAssertTrue(coordinator.storageCategories.isEmpty, "init 后 storageCategories 应为空")
        XCTAssertTrue(coordinator.assetCategoryStats.isEmpty, "init 后 assetCategoryStats 应为空")
        XCTAssertTrue(coordinator.vaultStorageItems.isEmpty, "init 后 vaultStorageItems 应为空")
        XCTAssertNil(coordinator.rawStorageStats, "init 后 rawStorageStats 应为 nil")
        XCTAssertEqual(coordinator.provenance.importedCount, 0, "init 后 provenance.importedCount 应为 0")
        XCTAssertEqual(coordinator.provenance.createdCount, 0, "init 后 provenance.createdCount 应为 0")
    }

    // MARK: - loadStats 正常路径

    /// 验证 loadStats 成功后 isLoading 恢复 false
    func testLoadStatsSuccessIsLoadingRestoresFalse() async throws {
        await coordinator.loadStats()
        XCTAssertFalse(coordinator.isLoading, "loadStats 完成后 isLoading 应恢复 false")
    }

    /// 验证 loadStats 成功后调用 logger.addLog 记录更新日志
    func testLoadStatsSuccessCallsLoggerAddLog() async throws {
        await coordinator.loadStats()
        XCTAssertEqual(recordableLogger.addLogCallCount, 1, "loadStats 应调用一次 addLog")
        XCTAssertEqual(recordableLogger.lastAction, .update, "addLog 的 action 应为 update")
        XCTAssertEqual(recordableLogger.lastModule, "Dashboard", "addLog 的 module 应为 Dashboard")
    }

    /// 验证 loadStats 成功后 totalPages 来自 knowledgeRepo.count()
    func testLoadStatsSuccessTotalPagesFromKnowledgeRepoCount() async throws {
        configurableKnowledgeRepo.stubCount = 42
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.totalPages, 42, "totalPages 应等于 knowledgeRepo.count() 返回值")
        XCTAssertEqual(configurableKnowledgeRepo.countCallCount, 1, "应调用一次 count()")
    }

    /// 验证 loadStats 成功后 storageCategories 包含 7 个分类
    func testLoadStatsSuccessStorageCategoriesContainsSevenCategories() async throws {
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.storageCategories.count, 7, "storageCategories 应包含 7 个分类（数据库/模型/插件/日志/导入/导出/缓存）")
    }

    /// 验证 loadStats 成功后 totalStorage 等于各分类 value 之和
    func testLoadStatsSuccessTotalStorageEqualsSumOfCategoryValues() async throws {
        let stats = StorageStats(
            databaseSize: 1000, logsSize: 200, exportsSize: 300,
            modelsSize: 400, pluginsSize: 500, cachesSize: 600
        )
        configurablePageStore.stubStorageStats = stats
        await coordinator.loadStats()
        let expected: Int64 = 1000 + 200 + 300 + 400 + 500 + 600
        XCTAssertEqual(coordinator.totalStorage, expected, "totalStorage 应等于各分类 value 之和")
    }

    /// 验证 loadStats 成功后 exportSize 来自 pageStore.getStorageStats().exportsSize
    func testLoadStatsSuccessExportSizeFromStorageStats() async throws {
        configurablePageStore.stubStorageStats = StorageStats(
            databaseSize: 0, logsSize: 0, exportsSize: 9999
        )
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.exportSize, 9999, "exportSize 应等于 StorageStats.exportsSize")
    }

    /// 验证 loadStats 成功后 exportCount 来自 logger.getLogEntries() 中 action==.export 的数量
    func testLoadStatsSuccessExportCountFromExportActionCountInLogEntries() async throws {
        let exportEntries = [
            LogEntry(action: .export, target: "导出1"),
            LogEntry(action: .export, target: "导出2"),
            LogEntry(action: .create, target: "创建1")
        ]
        recordableLogger.stubLogEntries = exportEntries
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.exportCount, 2, "exportCount 应等于 LogEntries 中 action==.export 的数量")
    }

    /// 验证 loadStats 成功后 monthlyStats 来自 governanceRepo.fetchMonthlyTokenStats()
    func testLoadStatsSuccessMonthlyStatsFromGovernanceRepo() async throws {
        configurableGovernanceRepo.stubMonthlyStats = [
            (month: "2026-01", total: 5000),
            (month: "2026-02", total: 8000)
        ]
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.monthlyStats.count, 2, "monthlyStats 应包含 2 个月度数据")
        XCTAssertEqual(coordinator.monthlyStats[0].month, "2026-01", "第一条月度 month 应匹配")
        XCTAssertEqual(coordinator.monthlyStats[0].total, 5000, "第一条月度 total 应匹配")
        XCTAssertEqual(coordinator.monthlyStats[1].month, "2026-02", "第二条月度 month 应匹配")
        XCTAssertEqual(coordinator.monthlyStats[1].total, 8000, "第二条月度 total 应匹配")
    }

    /// 验证 loadStats 成功后 dailyStats 包含本月每一天的占位数据
    func testLoadStatsSuccessDailyStatsContainsDailyPlaceholdersOfMonth() async throws {
        await coordinator.loadStats()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.year, .month], from: today)
        let startDate = calendar.date(from: components) ?? today
        let numberOfDays = (calendar.dateComponents([.day], from: startDate, to: today).day ?? 0) + 1
        XCTAssertEqual(coordinator.dailyStats.count, numberOfDays, "dailyStats 应包含本月至今每天的占位数据")
        for i in 1..<coordinator.dailyStats.count {
            XCTAssertLessThan(coordinator.dailyStats[i - 1].date, coordinator.dailyStats[i].date, "dailyStats 应按日期升序排列")
        }
    }

    /// 验证 loadStats 成功后 dailyStats 中匹配日期的数据被实际值覆盖
    func testLoadStatsSuccessDailyStatsMatchedDateOverwrittenByActual() async throws {
        let todayStr = todayDateString()
        configurableGovernanceRepo.stubDailyStats = [
            DailyAIStat(date: todayStr, tokens: 1234, requests: 56)
        ]
        await coordinator.loadStats()
        let todayEntry = coordinator.dailyStats.first { $0.dateString == todayStr }
        XCTAssertNotNil(todayEntry, "应存在今日的 dailyStats 条目")
        XCTAssertEqual(todayEntry?.tokens, 1234, "今日 tokens 应被实际值覆盖")
        XCTAssertEqual(todayEntry?.requests, 56, "今日 requests 应被实际值覆盖")
    }

    /// 验证 loadStats 成功后 dailyStats 中未匹配日期保持占位零值
    func testLoadStatsSuccessDailyStatsUnmatchedDateKeepsZero() async throws {
        configurableGovernanceRepo.stubDailyStats = [
            DailyAIStat(date: "2099-12-31", tokens: 9999, requests: 999)
        ]
        await coordinator.loadStats()
        XCTAssertTrue(coordinator.dailyStats.allSatisfy { $0.tokens == 0 && $0.requests == 0 }, "未匹配日期应保持占位零值")
    }

    /// 验证 loadStats 成功后 assetCategoryStats 按 ImportCategory 分类聚合
    func testLoadStatsSuccessAssetCategoryStatsAggregatedByCategory() async throws {
        let voiceRecord1 = makeRecord(category: .voice, size: 1000)
        let voiceRecord2 = makeRecord(category: .voice, size: 2000)
        let ocrRecord = makeRecord(category: .ocr, size: 5000)
        let fileRecord = makeRecord(category: .file, size: 10000)
        let manualRecord = makeRecord(category: .manual, size: 999)
        try? await mockImportRecordRepo.save(voiceRecord1)
        try? await mockImportRecordRepo.save(voiceRecord2)
        try? await mockImportRecordRepo.save(ocrRecord)
        try? await mockImportRecordRepo.save(fileRecord)
        try? await mockImportRecordRepo.save(manualRecord)
        await coordinator.loadStats()
        let voiceStats = coordinator.assetCategoryStats[ImportCategory.voice.rawValue]
        XCTAssertEqual(voiceStats?.count, 2, "voice 分类应聚合 2 条记录")
        XCTAssertEqual(voiceStats?.size, 3000, "voice 分类 size 应为 1000+2000")
        let ocrStats = coordinator.assetCategoryStats[ImportCategory.ocr.rawValue]
        XCTAssertEqual(ocrStats?.count, 1, "ocr 分类应聚合 1 条记录")
        XCTAssertEqual(ocrStats?.size, 5000, "ocr 分类 size 应为 5000")
        let fileStats = coordinator.assetCategoryStats[ImportCategory.file.rawValue]
        XCTAssertEqual(fileStats?.count, 1, "file 分类应聚合 1 条记录")
        XCTAssertEqual(fileStats?.size, 10000, "file 分类 size 应为 10000")
        XCTAssertNil(coordinator.assetCategoryStats[ImportCategory.manual.rawValue], "manual 分类不应出现在 assetCategoryStats")
    }

    /// 验证 loadStats 成功后 models 分类 value 取 stats.modelsSize 与 modelManagerSize 的较大值
    func testLoadStatsSuccessModelsCategoryValueTakesLarger() async throws {
        configurablePageStore.stubStorageStats = StorageStats(
            databaseSize: 0, logsSize: 0, exportsSize: 0,
            modelsSize: 1000
        )
        await coordinator.loadStats()
        let modelsCategory = coordinator.storageCategories.first { $0.label == L10n.Dashboard.System.models }
        XCTAssertNotNil(modelsCategory, "应存在 models 分类")
        XCTAssertEqual(modelsCategory?.value, 1000, "models 分类 value 应取 stats.modelsSize 与 modelManagerSize 的较大值")
    }

    // MARK: - loadStats 空数据路径

    /// 验证 loadStats 所有依赖返回空数据时状态属性保持安全默认值
    func testLoadStatsEmptyDataStatePropsKeepSafeDefaults() async throws {
        await coordinator.loadStats()
        XCTAssertFalse(coordinator.isLoading, "空数据后 isLoading 应恢复 false")
        XCTAssertEqual(coordinator.totalStorage, 0, "空数据后 totalStorage 应为 0")
        XCTAssertEqual(coordinator.exportCount, 0, "空数据后 exportCount 应为 0")
        XCTAssertEqual(coordinator.exportSize, 0, "空数据后 exportSize 应为 0")
        XCTAssertEqual(coordinator.totalPages, 0, "空数据后 totalPages 应为 0")
        XCTAssertTrue(coordinator.monthlyStats.isEmpty, "空数据后 monthlyStats 应为空")
        XCTAssertFalse(coordinator.dailyStats.isEmpty, "dailyStats 应包含本月占位数据（即使无实际数据）")
        XCTAssertEqual(coordinator.assetCategoryStats.count, 3, "assetCategoryStats 应包含 3 个分类（voice/ocr/file）")
        XCTAssertTrue(coordinator.assetCategoryStats.values.allSatisfy { $0.count == 0 && $0.size == 0 }, "空数据后各分类 count 和 size 应为 0")
    }

    // MARK: - loadStats 部分依赖失败路径

    /// 验证 loadStats 时 governanceRepo.fetchDailyAIStats 抛错 dailyStats 保持占位数据
    func testLoadStatsFetchDailyAIStatsThrowsDailyStatsKeepsPlaceholder() async throws {
        configurableGovernanceRepo.shouldThrowDailyStats = true
        await coordinator.loadStats()
        XCTAssertTrue(coordinator.dailyStats.isEmpty, "fetchDailyAIStats 抛错时 dailyStats 应保持初始空（guard 短路）")
        XCTAssertFalse(coordinator.isLoading, "即使部分依赖失败，loadStats 完成后 isLoading 应恢复 false")
    }

    /// 验证 loadStats 时 governanceRepo.fetchMonthlyTokenStats 抛错 monthlyStats 保持空
    func testLoadStatsFetchMonthlyTokenStatsThrowsMonthlyStatsKeepsEmpty() async throws {
        configurableGovernanceRepo.shouldThrowMonthlyStats = true
        await coordinator.loadStats()
        XCTAssertTrue(coordinator.monthlyStats.isEmpty, "fetchMonthlyTokenStats 抛错时 monthlyStats 应保持空")
    }

    /// 验证 loadStats 时 knowledgeRepo.count() 抛错 totalPages 降级为 0
    func testLoadStatsCountThrowsTotalPagesDegradesToZero() async throws {
        configurableKnowledgeRepo.stubCount = 100
        configurableKnowledgeRepo.shouldThrowCount = true
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.totalPages, 0, "count() 抛错时 totalPages 应通过 try? 降级为 0")
    }

    /// 验证 loadStats 时 knowledgeRepo.fetchAll() 抛错 rawStorageStats 保持 nil
    func testLoadStatsFetchAllThrowsRawStorageStatsKeepsNil() async throws {
        configurableKnowledgeRepo.shouldThrowFetchAll = true
        await coordinator.loadStats()
        XCTAssertNil(coordinator.rawStorageStats, "fetchAll() 抛错时 rawStorageStats 应保持 nil（guard 短路）")
    }

    /// 验证 loadStats 时 importRecordRepo.totalStorageSize() 抛错 导入分类 value 降级为 0
    func testLoadStatsTotalStorageSizeThrowsImportCategoryValueDegradesToZero() async throws {
        await coordinator.loadStats()
        let importCategory = coordinator.storageCategories.first { $0.label == L10n.Dashboard.stats.storageImport }
        XCTAssertNotNil(importCategory, "应存在导入分类")
        XCTAssertEqual(importCategory?.value, 0, "无导入记录时导入分类 value 应为 0")
    }

    // MARK: - loadStats isLoading 状态变化

    /// 验证 loadStats 执行前 isLoading 为 true，完成后为 false
    func testLoadStatsBeforeIsLoadingTrueAfterFalse() async throws {
        XCTAssertTrue(coordinator.isLoading, "loadStats 执行前 isLoading 应为 true")
        await coordinator.loadStats()
        XCTAssertFalse(coordinator.isLoading, "loadStats 完成后 isLoading 应为 false")
    }

    // MARK: - 多次 loadStats 幂等性

    /// 验证多次调用 loadStats 后状态一致（幂等性）
    func testLoadStatsMultipleCallsStateConsistent() async throws {
        configurableKnowledgeRepo.stubCount = 10
        configurableGovernanceRepo.stubMonthlyStats = [(month: "2026-01", total: 1000)]
        configurablePageStore.stubStorageStats = StorageStats(databaseSize: 500, logsSize: 100, exportsSize: 200)
        await coordinator.loadStats()
        let firstTotalPages = coordinator.totalPages
        let firstMonthlyCount = coordinator.monthlyStats.count
        let firstTotalStorage = coordinator.totalStorage
        let firstStorageCategoriesCount = coordinator.storageCategories.count
        await coordinator.loadStats()
        let secondTotalPages = coordinator.totalPages
        let secondMonthlyCount = coordinator.monthlyStats.count
        let secondTotalStorage = coordinator.totalStorage
        let secondStorageCategoriesCount = coordinator.storageCategories.count
        XCTAssertEqual(firstTotalPages, secondTotalPages, "多次 loadStats 后 totalPages 应一致")
        XCTAssertEqual(firstMonthlyCount, secondMonthlyCount, "多次 loadStats 后 monthlyStats.count 应一致")
        XCTAssertEqual(firstTotalStorage, secondTotalStorage, "多次 loadStats 后 totalStorage 应一致")
        XCTAssertEqual(firstStorageCategoriesCount, secondStorageCategoriesCount, "多次 loadStats 后 storageCategories.count 应一致")
    }

    /// 验证多次调用 loadStats 后 isLoading 始终恢复 false
    func testLoadStatsMultipleCallsIsLoadingAlwaysRestoresFalse() async throws {
        await coordinator.loadStats()
        XCTAssertFalse(coordinator.isLoading, "第一次 loadStats 后 isLoading 应为 false")
        await coordinator.loadStats()
        XCTAssertFalse(coordinator.isLoading, "第二次 loadStats 后 isLoading 应为 false")
    }

    /// 验证多次调用 loadStats 后 logger.addLog 调用次数递增
    func testLoadStatsMultipleCallsAddLogCountIncrements() async throws {
        await coordinator.loadStats()
        let firstCount = recordableLogger.addLogCallCount
        XCTAssertEqual(firstCount, 1, "第一次 loadStats 后 addLog 应调用 1 次")
        await coordinator.loadStats()
        let secondCount = recordableLogger.addLogCallCount
        XCTAssertEqual(secondCount, 2, "第二次 loadStats 后 addLog 应调用 2 次")
    }

    // MARK: - provenance 属性

    /// 验证 loadStats 后 provenance 保持初始零值（当前实现未填充 provenance）
    func testLoadStatsProvenanceKeepsInitialZero() async throws {
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.provenance.importedCount, 0, "provenance.importedCount 应保持初始零值（loadStats 未填充）")
        XCTAssertEqual(coordinator.provenance.importedSize, 0, "provenance.importedSize 应保持初始零值")
        XCTAssertEqual(coordinator.provenance.createdCount, 0, "provenance.createdCount 应保持初始零值")
        XCTAssertEqual(coordinator.provenance.createdSize, 0, "provenance.createdSize 应保持初始零值")
    }

    // MARK: - 延迟相关属性

    /// 验证 loadStats 后延迟相关属性保持初始零值（当前实现未填充）
    func testLoadStatsLatencyPropsKeepInitialZero() async throws {
        await coordinator.loadStats()
        XCTAssertEqual(coordinator.avgLatency, 0, "avgLatency 应保持初始零值")
        XCTAssertEqual(coordinator.maxLatency, 0, "maxLatency 应保持初始零值")
        XCTAssertEqual(coordinator.minLatency, 0, "minLatency 应保持初始零值")
        XCTAssertEqual(coordinator.latencyCount, 0, "latencyCount 应保持初始零值")
    }
}

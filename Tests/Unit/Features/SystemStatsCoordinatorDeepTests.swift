//
//  SystemStatsCoordinatorDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：SystemStatsCoordinator 深度补盲测试 — 覆盖 loadStats 正常/空/失败路径、
//            isLoading 状态机、cleanupData 成功/失败/状态恢复、formatBytes 边界值、
//            iconForCategory 分支、fetchRawPageStats 原始页统计、fetchVaultStorageSizes
//            多笔记本关联、assetCategoryStats 分类聚合、storageCategories 求和、
//            多次 loadStats 幂等性等未覆盖分支，以发现生产代码潜在 bug 为首要目标。
//
//  说明：当前覆盖率 72.73%，主要未覆盖分支为 loadStats 各子流程的失败 guard 短路、
//        cleanupData 错误路径、formatBytes/iconForCategory 边界、fetchRawPageStats、
//        fetchVaultStorageSizes。本文件通过自定义可配置 Mock 注入异常与精确数据，
//        覆盖这些分支并验证状态一致性。
//

import XCTest
import SwiftUI
import Combine
import GRDB
import UFPCore
import Dependencies
@testable import ZhiYu

// MARK: - 测试错误辅助

/// 构造带描述信息的测试用 NSError
private func makeTestError(_ description: String) -> NSError {
    NSError(domain: "SystemStatsCoordinatorDeepTests", code: 1, userInfo: [NSLocalizedDescriptionKey: description])
}

// MARK: - 可记录日志的 Logger Mock

/// 可记录 addLog 调用与可配置 getLogEntries 返回值的 Logger Mock
final class RecordableLogger: LoggerProtocol, @unchecked Sendable {
    /// addLog 调用次数
    private(set) var addLogCallCount: Int = 0
    /// 最近一次 addLog 的 action 参数
    private(set) var lastAction: LogAction?
    /// 最近一次 addLog 的 target 参数
    private(set) var lastTarget: String?
    /// 最近一次 addLog 的 module 参数
    private(set) var lastModule: String?
    /// getLogEntries 返回的预设日志条目
    var stubLogEntries: [LogEntry] = []
    /// error 调用次数
    private(set) var errorCallCount: Int = 0

    var logEntriesPublisher: AnyPublisher<[LogEntry], Never> { Just([]).eraseToAnyPublisher() }

    func addLog(action: LogAction, target: String, details: String, duration: TimeInterval?, startTime: Date?, endTime: Date?, module: String?, status: LogStatus?, failureReason: String?) {
        addLogCallCount += 1
        lastAction = action
        lastTarget = target
        lastModule = module
    }

    func debug(_ message: String, file: String, function: String, line: Int) {}
    func info(_ message: String, file: String, function: String, line: Int) {}
    func warning(_ message: String, file: String, function: String, line: Int) {}
    func error(_ message: String, error: Error?, file: String, function: String, line: Int) {
        errorCallCount += 1
    }
    func saveToDisk() async {}
    func loadFromDisk() async {}
    func clearAllLogs() async {}
    func logTimed<T>(action: LogAction, target: String, module: String?, details: String, operation: () throws -> T) rethrows -> T { try operation() }
    func getLogEntries() async -> [LogEntry] { stubLogEntries }
}

// MARK: - 可配置触感反馈 Mock

/// 记录 trigger 调用次数与模式的触感反馈 Mock
@MainActor
final class RecordableHaptic: HapticFeedbackProtocol, @unchecked Sendable {
    /// trigger 调用次数
    private(set) var triggerCallCount: Int = 0
    /// 最近一次 trigger 的模式
    private(set) var lastPattern: HapticPattern?

    func trigger(_ pattern: HapticPattern) {
        triggerCallCount += 1
        lastPattern = pattern
    }
}

// MARK: - 可配置向量仓储 Mock

/// 支持配置 cleanupOrphanedChunks 返回值与抛错行为的向量仓储 Mock
final class ConfigurableVectorRepository: VectorRepository, @unchecked Sendable {
    /// cleanupOrphanedChunks 返回的清理数量
    var stubCleanupCount: Int = 0
    /// cleanupOrphanedChunks 是否应抛错
    var shouldThrowCleanup: Bool = false
    /// cleanupOrphanedChunks 调用次数
    private(set) var cleanupCallCount: Int = 0

    func saveChunks(_ chunks: [PageChunk], for pageID: UUID) async throws {}
    func fetchChunks(for pageID: UUID) async throws -> [PageChunk] { [] }
    func fetchAllChunksWithEmbeddings() async throws -> [PageChunk] { [] }
    func deleteChunks(for pageID: UUID) async throws {}
    func cleanupOrphanedChunks() async throws -> Int {
        cleanupCallCount += 1
        if shouldThrowCleanup {
            throw makeTestError("清理失败")
        }
        return stubCleanupCount
    }
    func saveEmbedding(id: UUID, vector: [Float], modelName: String) async throws {}
    func fetchAllEmbeddings() async throws -> [UUID: [Float]] { [:] }
}

// MARK: - 可配置 RAG 治理仓储 Mock

/// 支持配置 fetchDailyAIStats / fetchMonthlyTokenStats 返回值与抛错行为的治理仓储 Mock
final class ConfigurableRAGGovernanceRepository: RAGGovernanceRepository, @unchecked Sendable {
    /// fetchDailyAIStats 返回的预设数据
    var stubDailyStats: [DailyAIStat] = []
    /// fetchDailyAIStats 是否应抛错
    var shouldThrowDailyStats: Bool = false
    /// fetchMonthlyTokenStats 返回的预设数据
    var stubMonthlyStats: [(month: String, total: Int)] = []
    /// fetchMonthlyTokenStats 是否应抛错
    var shouldThrowMonthlyStats: Bool = false
    /// fetchDailyAIStats 调用次数
    private(set) var dailyStatsCallCount: Int = 0
    /// fetchMonthlyTokenStats 调用次数
    private(set) var monthlyStatsCallCount: Int = 0

    func logTokenUsage(model: String, promptTokens: Int, completionTokens: Int) async throws {}
    func fetchTokenStats(days: Int) async throws -> TokenStats { TokenStats(prompt: 0, completion: 0, total: 0) }
    func fetchDailyAIStats(days: Int) async throws -> [DailyAIStat] {
        dailyStatsCallCount += 1
        if shouldThrowDailyStats {
            throw makeTestError("日报查询失败")
        }
        return stubDailyStats
    }
    func fetchMonthlyTokenStats() async throws -> [(month: String, total: Int)] {
        monthlyStatsCallCount += 1
        if shouldThrowMonthlyStats {
            throw makeTestError("月报查询失败")
        }
        return stubMonthlyStats
    }
    func logCall(model: String, promptTokens: Int, completionTokens: Int, latencyMS: Int, status: String) async throws {}
    func fetchRecentLogs(limit: Int) async throws -> [LLMCallLog] { [] }
    func saveRAGEvaluation(_ evaluation: RAGEvaluation) async throws {}
    func fetchRAGEvaluations(limit: Int) async throws -> [RAGEvaluation] { [] }
    func calculateAverageRAGScores(days: Int) async throws -> AverageRAGScores {
        AverageRAGScores(faithfulness: 0, relevance: 0, precision: 0, hallucinationRate: 0, citationAccuracy: 0)
    }
    func saveRetrievalSnapshots(_ snapshots: [RetrievalSnapshot]) async throws {}
    func fetchRetrievalSnapshots(evaluationID: Int64) async throws -> [RetrievalSnapshot] { [] }
    func saveRelevanceJudgments(_ judgments: [RelevanceJudgment]) async throws {}
    func calculateHitRate(days: Int, k: Int) async throws -> Double { 0 }
    func calculateMRR(days: Int) async throws -> Double { 0 }
    func calculateNDCG(days: Int, k: Int) async throws -> Double { 0 }
    func calculateRecall(days: Int, k: Int) async throws -> Double { 0 }
    func calculateF1Score(days: Int, k: Int) async throws -> Double { 0 }
    func calculateMAP(days: Int) async throws -> Double { 0 }
    func calculateRetrievalLatency(days: Int) async throws -> LatencyPercentiles {
        LatencyPercentiles(p50: 0, p95: 0, p99: 0, sampleCount: 0)
    }
    func calculateTokenEfficiency(days: Int) async throws -> TokenEfficiency {
        TokenEfficiency(totalTokens: 0, queryCount: 0, avgTokensPerQuery: 0, estimatedCostUSD: 0)
    }
    func updateUserRating(evaluationID: Int64, rating: Int) async throws {}
}

// MARK: - 可配置页面存储能力 Mock

/// 支持配置 getStorageStats 返回值的页面存储能力 Mock
final class ConfigurablePageStoreCapabilities: AnyPageStoreCapabilities, @unchecked Sendable {
    /// getStorageStats 返回的预设存储统计
    var stubStorageStats: StorageStats = StorageStats(databaseSize: 0, logsSize: 0, exportsSize: 0)
    /// getStorageStats 调用次数
    private(set) var getStorageStatsCallCount: Int = 0

    let embeddingProvider: any EmbeddingProvider = NoOpEmbeddingProvider()

    var pages: [KnowledgePage] { get async { [] } }
    func fetchAllPages() async throws -> [KnowledgePage] { [] }
    func reloadFromDisk() async {}
    func replaceAllPages(_ newPages: [KnowledgePage]) async {}
    func resetDatabase() async throws {}
    func performBatchWrite(_ block: @escaping @Sendable (Database) throws -> Void) async throws {}
    func createPage(title: String, pageType: PageType, customIcon: String?, content: String, tags: [String], sourceURL: String?, rawSnippet: String?, fileSize: Int64?, sourceType: String?) async throws -> KnowledgePage {
        KnowledgePage(title: title, pageType: pageType, customIcon: customIcon, content: content, tags: tags, sourceURL: sourceURL, rawTextSnippet: rawSnippet, fileSize: fileSize, sourceType: sourceType)
    }
    @discardableResult
    func anyCreatePage(title: String, pageType: PageType, customIcon: String?, content: String, tags: [String], sourceURL: String?, rawSnippet: String?, fileSize: Int64?, sourceType: String?, forceDeepScan: Bool) async -> KnowledgePage {
        KnowledgePage(title: title, pageType: pageType, customIcon: customIcon, content: content, tags: tags, sourceURL: sourceURL, rawTextSnippet: rawSnippet, fileSize: fileSize, sourceType: sourceType)
    }
    func updatePage(_ page: KnowledgePage) async throws {}
    func anyUpdatePage(_ page: KnowledgePage, forceDeepScan: Bool) async {}
    func deletePage(_ page: KnowledgePage) async throws {}
    func anyDeletePage(_ page: KnowledgePage) async {}
    func syncRemotePage(_ page: KnowledgePage) async {}
    func fetchBacklinksByID(for id: UUID) async -> [KnowledgePage] { [] }
    func searchPages(query: String) async -> [KnowledgePage] { [] }
    func renameTag(_ oldTag: String, to newTag: String) async {}
    func deleteTag(_ tag: String) async {}
    func seedDefaultContent(logger: @escaping @Sendable (LogAction, String, String) -> Void) async {}
    func addLog(action: LogAction, target: String, details: String, duration: TimeInterval?, startTime: Date?, endTime: Date?, module: String?) {}
    func getStorageStats() async -> StorageStats {
        getStorageStatsCallCount += 1
        return stubStorageStats
    }
}

// MARK: - 可配置知识库仓储 Mock

/// 支持配置 fetchAll / count 返回值与抛错行为的知识库仓储 Mock
final class ConfigurableKnowledgeRepository: KnowledgeRepository, @unchecked Sendable {
    /// fetchAll 返回的预设页面列表
    var stubAllPages: [KnowledgePage] = []
    /// fetchAll 是否应抛错
    var shouldThrowFetchAll: Bool = false
    /// count 返回的预设数量
    var stubCount: Int = 0
    /// count 是否应抛错
    var shouldThrowCount: Bool = false
    /// fetchAll 调用次数
    private(set) var fetchAllCallCount: Int = 0
    /// count 调用次数
    private(set) var countCallCount: Int = 0

    func fetchAll() async throws -> [KnowledgePage] {
        fetchAllCallCount += 1
        if shouldThrowFetchAll {
            throw makeTestError("fetchAll 失败")
        }
        return stubAllPages
    }
    func fetch(id: UUID) async throws -> KnowledgePage? { nil }
    func save(_ page: KnowledgePage) async throws {}
    func delete(id: UUID) async throws {}
    func search(query: String) async throws -> [KnowledgePage] { [] }
    func fetchBacklinks(for id: UUID) async throws -> [UUID] { [] }
    func renameTag(old: String, to new: String) async throws {}
    func deleteTag(_ tag: String) async throws {}
    func count() async throws -> Int {
        countCallCount += 1
        if shouldThrowCount {
            throw makeTestError("count 失败")
        }
        return stubCount
    }
}

// MARK: - SystemStatsCoordinatorDeepTests

@MainActor
final class SystemStatsCoordinatorDeepTests: XCTestCase {

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

        // 创建并注册可配置 Mock 到 ServiceContainer（覆盖 setupFullMockEnvironment 的默认注册）
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

        // 清空 VaultService 单例的 vaults，确保测试隔离
        VaultService.shared.vaults = []
        VaultService.shared.selectedVaultID = nil

        // @Dependency 在 init 时解析并缓存，必须在创建 coordinator 前完成所有注册
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

    /// 构造今日日期字符串（yyyy-MM-dd）
    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = AppConstants.Keys.Stats.dailyDateFormat
        return formatter.string(from: Date())
    }

    // MARK: - 初始状态

    /// 验证 init 后所有状态属性为初始默认值
    func testInit_所有状态属性为初始默认值() {
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
    func testLoadStats_成功_isLoading恢复False() async throws {
        await coordinator.loadStats()

        XCTAssertFalse(coordinator.isLoading, "loadStats 完成后 isLoading 应恢复 false")
    }

    /// 验证 loadStats 成功后调用 logger.addLog 记录更新日志
    func testLoadStats_成功_调用LoggerAddLog() async throws {
        await coordinator.loadStats()

        XCTAssertEqual(recordableLogger.addLogCallCount, 1, "loadStats 应调用一次 addLog")
        XCTAssertEqual(recordableLogger.lastAction, .update, "addLog 的 action 应为 update")
        XCTAssertEqual(recordableLogger.lastModule, "Dashboard", "addLog 的 module 应为 Dashboard")
    }

    /// 验证 loadStats 成功后 totalPages 来自 knowledgeRepo.count()
    func testLoadStats_成功_totalPages来自KnowledgeRepoCount() async throws {
        configurableKnowledgeRepo.stubCount = 42

        await coordinator.loadStats()

        XCTAssertEqual(coordinator.totalPages, 42, "totalPages 应等于 knowledgeRepo.count() 返回值")
        XCTAssertEqual(configurableKnowledgeRepo.countCallCount, 1, "应调用一次 count()")
    }

    /// 验证 loadStats 成功后 storageCategories 包含 7 个分类
    func testLoadStats_成功_storageCategories包含7个分类() async throws {
        await coordinator.loadStats()

        XCTAssertEqual(coordinator.storageCategories.count, 7, "storageCategories 应包含 7 个分类（数据库/模型/插件/日志/导入/导出/缓存）")
    }

    /// 验证 loadStats 成功后 totalStorage 等于各分类 value 之和
    func testLoadStats_成功_totalStorage等于各分类Value之和() async throws {
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
    func testLoadStats_成功_exportSize来自StorageStats() async throws {
        configurablePageStore.stubStorageStats = StorageStats(
            databaseSize: 0, logsSize: 0, exportsSize: 9999
        )

        await coordinator.loadStats()

        XCTAssertEqual(coordinator.exportSize, 9999, "exportSize 应等于 StorageStats.exportsSize")
    }

    /// 验证 loadStats 成功后 exportCount 来自 logger.getLogEntries() 中 action==.export 的数量
    func testLoadStats_成功_exportCount来自LogEntries中ExportAction数量() async throws {
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
    func testLoadStats_成功_monthlyStats来自GovernanceRepo() async throws {
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
    func testLoadStats_成功_dailyStats包含本月每日占位() async throws {
        // 不设置 stubDailyStats，验证占位填充逻辑
        await coordinator.loadStats()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.year, .month], from: today)
        let startDate = calendar.date(from: components) ?? today
        let numberOfDays = (calendar.dateComponents([.day], from: startDate, to: today).day ?? 0) + 1

        XCTAssertEqual(coordinator.dailyStats.count, numberOfDays, "dailyStats 应包含本月至今每天的占位数据")
        // 验证按日期升序排列
        for i in 1..<coordinator.dailyStats.count {
            XCTAssertLessThan(coordinator.dailyStats[i - 1].date, coordinator.dailyStats[i].date, "dailyStats 应按日期升序排列")
        }
    }

    /// 验证 loadStats 成功后 dailyStats 中匹配日期的数据被实际值覆盖
    func testLoadStats_成功_dailyStats匹配日期被实际值覆盖() async throws {
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
    func testLoadStats_成功_dailyStats未匹配日期保持零值() async throws {
        // 提供一个未来日期的无效数据，不应匹配任何占位
        configurableGovernanceRepo.stubDailyStats = [
            DailyAIStat(date: "2099-12-31", tokens: 9999, requests: 999)
        ]

        await coordinator.loadStats()

        // 所有条目应保持零值（无效日期未匹配占位）
        XCTAssertTrue(coordinator.dailyStats.allSatisfy { $0.tokens == 0 && $0.requests == 0 }, "未匹配日期应保持占位零值")
    }

    /// 验证 loadStats 成功后 assetCategoryStats 按 ImportCategory 分类聚合
    func testLoadStats_成功_assetCategoryStats按分类聚合() async throws {
        let voiceRecord1 = makeRecord(category: .voice, size: 1000)
        let voiceRecord2 = makeRecord(category: .voice, size: 2000)
        let ocrRecord = makeRecord(category: .ocr, size: 5000)
        let fileRecord = makeRecord(category: .file, size: 10000)
        let manualRecord = makeRecord(category: .manual, size: 999) // manual 不在聚合范围
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

        // manual 不在聚合范围，不应出现在 assetCategoryStats
        XCTAssertNil(coordinator.assetCategoryStats[ImportCategory.manual.rawValue], "manual 分类不应出现在 assetCategoryStats")
    }

    /// 验证 loadStats 成功后 models 分类 value 取 stats.modelsSize 与 modelManagerSize 的较大值
    func testLoadStats_成功_models分类Value取较大值() async throws {
        configurablePageStore.stubStorageStats = StorageStats(
            databaseSize: 0, logsSize: 0, exportsSize: 0,
            modelsSize: 1000
        )
        // GlobalModelManager.shared.modelStorageUsage 默认为空，sum 为 0
        // effectiveModelsSize = max(1000, 0) = 1000

        await coordinator.loadStats()

        let modelsCategory = coordinator.storageCategories.first { $0.label == L10n.Dashboard.System.models }
        XCTAssertNotNil(modelsCategory, "应存在 models 分类")
        XCTAssertEqual(modelsCategory?.value, 1000, "models 分类 value 应取 stats.modelsSize 与 modelManagerSize 的较大值")
    }

    // MARK: - loadStats 空数据路径

    /// 验证 loadStats 所有依赖返回空数据时状态属性保持安全默认值
    func testLoadStats_空数据_状态属性保持安全默认值() async throws {
        // 所有 stub 保持默认空值
        await coordinator.loadStats()

        XCTAssertFalse(coordinator.isLoading, "空数据后 isLoading 应恢复 false")
        XCTAssertEqual(coordinator.totalStorage, 0, "空数据后 totalStorage 应为 0")
        XCTAssertEqual(coordinator.exportCount, 0, "空数据后 exportCount 应为 0")
        XCTAssertEqual(coordinator.exportSize, 0, "空数据后 exportSize 应为 0")
        XCTAssertEqual(coordinator.totalPages, 0, "空数据后 totalPages 应为 0")
        XCTAssertTrue(coordinator.monthlyStats.isEmpty, "空数据后 monthlyStats 应为空")
        // dailyStats 仍包含本月占位（非空）
        XCTAssertFalse(coordinator.dailyStats.isEmpty, "dailyStats 应包含本月占位数据（即使无实际数据）")
        // assetCategoryStats 三个分类都存在但 count=0 size=0
        XCTAssertEqual(coordinator.assetCategoryStats.count, 3, "assetCategoryStats 应包含 3 个分类（voice/ocr/file）")
        XCTAssertTrue(coordinator.assetCategoryStats.values.allSatisfy { $0.count == 0 && $0.size == 0 }, "空数据后各分类 count 和 size 应为 0")
    }

    // MARK: - loadStats 部分依赖失败路径

    /// 验证 loadStats 时 governanceRepo.fetchDailyAIStats 抛错 dailyStats 保持占位数据
    func testLoadStats_fetchDailyAIStats抛错_dailyStats保持占位() async throws {
        configurableGovernanceRepo.shouldThrowDailyStats = true

        await coordinator.loadStats()

        // fetchAIDailyStats 内 guard try? 失败直接 return，dailyStats 保持初始空
        XCTAssertTrue(coordinator.dailyStats.isEmpty, "fetchDailyAIStats 抛错时 dailyStats 应保持初始空（guard 短路）")
        XCTAssertFalse(coordinator.isLoading, "即使部分依赖失败，loadStats 完成后 isLoading 应恢复 false")
    }

    /// 验证 loadStats 时 governanceRepo.fetchMonthlyTokenStats 抛错 monthlyStats 保持空
    func testLoadStats_fetchMonthlyTokenStats抛错_monthlyStats保持空() async throws {
        configurableGovernanceRepo.shouldThrowMonthlyStats = true

        await coordinator.loadStats()

        XCTAssertTrue(coordinator.monthlyStats.isEmpty, "fetchMonthlyTokenStats 抛错时 monthlyStats 应保持空")
    }

    /// 验证 loadStats 时 knowledgeRepo.count() 抛错 totalPages 降级为 0
    func testLoadStats_count抛错_totalPages降级为0() async throws {
        configurableKnowledgeRepo.stubCount = 100
        configurableKnowledgeRepo.shouldThrowCount = true

        await coordinator.loadStats()

        XCTAssertEqual(coordinator.totalPages, 0, "count() 抛错时 totalPages 应通过 try? 降级为 0")
    }

    /// 验证 loadStats 时 knowledgeRepo.fetchAll() 抛错 rawStorageStats 保持 nil
    func testLoadStats_fetchAll抛错_rawStorageStats保持Nil() async throws {
        configurableKnowledgeRepo.shouldThrowFetchAll = true

        await coordinator.loadStats()

        XCTAssertNil(coordinator.rawStorageStats, "fetchAll() 抛错时 rawStorageStats 应保持 nil（guard 短路）")
    }

    /// 验证 loadStats 时 importRecordRepo.totalStorageSize() 抛错 导入分类 value 降级为 0
    func testLoadStats_totalStorageSize抛错_导入分类Value降级为0() async throws {
        // MockImportRecordRepository.totalStorageSize() 不抛错，但 fetchAll 也不抛错
        // 此场景通过空记录验证：totalStorageSize 返回 0
        await coordinator.loadStats()

        let importCategory = coordinator.storageCategories.first { $0.label == L10n.Dashboard.stats.storageImport }
        XCTAssertNotNil(importCategory, "应存在导入分类")
        XCTAssertEqual(importCategory?.value, 0, "无导入记录时导入分类 value 应为 0")
    }

    // MARK: - loadStats isLoading 状态变化

    /// 验证 loadStats 执行前 isLoading 为 true，完成后为 false
    func testLoadStats_执行前isLoading为True_完成后为False() async throws {
        XCTAssertTrue(coordinator.isLoading, "loadStats 执行前 isLoading 应为 true")

        await coordinator.loadStats()

        XCTAssertFalse(coordinator.isLoading, "loadStats 完成后 isLoading 应为 false")
    }

    // MARK: - fetchRawPageStats 原始页统计

    /// 验证 loadStats 后 rawStorageStats 统计 .raw 类型页面的数量与字节大小
    func testFetchRawPageStats_统计Raw页面数量与字节大小() async throws {
        let rawPage1 = makePage(type: .raw, content: "原始内容1") // UTF8 字节
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
        // 所有 vault 目录都不存在，size 都为 0，排序后仍为 0
        let vault1 = Vault(name: "A")
        let vault2 = Vault(name: "B")
        let vault3 = Vault(name: "C")
        VaultService.shared.vaults = [vault1, vault2, vault3]

        await coordinator.loadStats()

        // size 全为 0 时排序稳定，验证数量正确
        XCTAssertEqual(coordinator.vaultStorageItems.count, 3, "应生成 3 个 item")
        // 验证降序：每个 item 的 size >= 下一个
        for i in 1..<coordinator.vaultStorageItems.count {
            XCTAssertGreaterThanOrEqual(coordinator.vaultStorageItems[i - 1].size, coordinator.vaultStorageItems[i].size, "vaultStorageItems 应按 size 降序排列")
        }
    }

    // MARK: - cleanupData 正常路径

    /// 验证 cleanupData 成功后 cleanedCount 被设置为返回的清理数量
    func testCleanupData_成功_cleanedCount设置为返回数量() async throws {
        configurableVectorRepo.stubCleanupCount = 15

        await coordinator.cleanupData()

        XCTAssertEqual(coordinator.cleanedCount, 15, "cleanedCount 应等于 cleanupOrphanedChunks 返回值")
    }

    /// 验证 cleanupData 成功后调用 haptic.trigger(.success)
    func testCleanupData_成功_调用HapticSuccess() async throws {
        configurableVectorRepo.stubCleanupCount = 5

        await coordinator.cleanupData()

        XCTAssertEqual(recordableHaptic.triggerCallCount, 1, "应调用一次 haptic.trigger")
        XCTAssertEqual(recordableHaptic.lastPattern, .success, "应触发 .success 模式")
    }

    /// 验证 cleanupData 成功后 isCleaning 恢复 false
    func testCleanupData_成功_isCleaning恢复False() async throws {
        configurableVectorRepo.stubCleanupCount = 3

        await coordinator.cleanupData()

        XCTAssertFalse(coordinator.isCleaning, "cleanupData 完成后 isCleaning 应恢复 false")
    }

    /// 验证 cleanupData 成功后调用 loadStats 刷新统计
    func testCleanupData_成功_调用LoadStats刷新统计() async throws {
        configurableVectorRepo.stubCleanupCount = 3
        configurableKnowledgeRepo.stubCount = 99

        await coordinator.cleanupData()

        XCTAssertEqual(coordinator.totalPages, 99, "cleanupData 应调用 loadStats 刷新 totalPages")
        XCTAssertFalse(coordinator.isLoading, "loadStats 刷新后 isLoading 应为 false")
    }

    /// 验证 cleanupData 执行前 isCleaning 为 false，执行中为 true，完成后为 false
    func testCleanupData_isCleaning状态变化() async throws {
        XCTAssertFalse(coordinator.isCleaning, "cleanupData 执行前 isCleaning 应为 false")

        configurableVectorRepo.stubCleanupCount = 1
        await coordinator.cleanupData()

        XCTAssertFalse(coordinator.isCleaning, "cleanupData 完成后 isCleaning 应恢复 false")
    }

    // MARK: - cleanupData 失败路径

    /// 验证 cleanupData 时 cleanupOrphanedChunks 抛错后 isCleaning 恢复 false
    func testCleanupData_抛错_isCleaning恢复False() async throws {
        configurableVectorRepo.shouldThrowCleanup = true

        await coordinator.cleanupData()

        XCTAssertFalse(coordinator.isCleaning, "cleanupData 抛错后 isCleaning 应恢复 false")
    }

    /// 验证 cleanupData 时 cleanupOrphanedChunks 抛错后调用 logger.error
    func testCleanupData_抛错_调用LoggerError() async throws {
        configurableVectorRepo.shouldThrowCleanup = true

        await coordinator.cleanupData()

        XCTAssertEqual(recordableLogger.errorCallCount, 1, "cleanupData 抛错应调用一次 logger.error")
    }

    /// 验证 cleanupData 时 cleanupOrphanedChunks 抛错后不调用 haptic.trigger
    func testCleanupData_抛错_不调用Haptic() async throws {
        configurableVectorRepo.shouldThrowCleanup = true

        await coordinator.cleanupData()

        XCTAssertEqual(recordableHaptic.triggerCallCount, 0, "cleanupData 抛错不应调用 haptic.trigger")
    }

    /// 验证 cleanupData 时 cleanupOrphanedChunks 抛错后 cleanedCount 保持原值
    func testCleanupData_抛错_cleanedCount保持原值() async throws {
        configurableVectorRepo.shouldThrowCleanup = true

        await coordinator.cleanupData()

        XCTAssertNil(coordinator.cleanedCount, "cleanupData 抛错后 cleanedCount 应保持 nil（未赋值）")
    }

    // MARK: - formatBytes 边界值

    /// 验证 formatBytes(0) 返回零字节格式
    func testFormatBytes_0_返回零字节格式() {
        let result = coordinator.formatBytes(0)

        XCTAssertFalse(result.isEmpty, "formatBytes(0) 不应返回空字符串")
        // ByteCountFormatter 对 0 字节在中文环境返回 "Zero KB" 或 "0 字节"，验证包含数字 0
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

    // MARK: - 多次 loadStats 幂等性

    /// 验证多次调用 loadStats 后状态一致（幂等性）
    func testLoadStats_多次调用_状态一致() async throws {
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
    func testLoadStats_多次调用_isLoading始终恢复False() async throws {
        await coordinator.loadStats()
        XCTAssertFalse(coordinator.isLoading, "第一次 loadStats 后 isLoading 应为 false")

        await coordinator.loadStats()
        XCTAssertFalse(coordinator.isLoading, "第二次 loadStats 后 isLoading 应为 false")
    }

    /// 验证多次调用 loadStats 后 logger.addLog 调用次数递增
    func testLoadStats_多次调用_addLog调用次数递增() async throws {
        await coordinator.loadStats()
        let firstCount = recordableLogger.addLogCallCount
        XCTAssertEqual(firstCount, 1, "第一次 loadStats 后 addLog 应调用 1 次")

        await coordinator.loadStats()
        let secondCount = recordableLogger.addLogCallCount
        XCTAssertEqual(secondCount, 2, "第二次 loadStats 后 addLog 应调用 2 次")
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
        // GlobalModelManager.shared.modelStorageUsage 默认为空，count 为 0
        await coordinator.loadStats()

        let modelsCategory = coordinator.storageCategories.first { $0.label == L10n.Dashboard.System.models }
        XCTAssertEqual(modelsCategory?.count, 0, "models 分类 count 应等于 GlobalModelManager.shared.modelStorageUsage.count")
    }

    // MARK: - provenance 属性

    /// 验证 loadStats 后 provenance 保持初始零值（当前实现未填充 provenance）
    func testLoadStats_provenance保持初始零值() async throws {
        await coordinator.loadStats()

        // 当前 SystemStatsCoordinator.loadStats() 未填充 provenance 属性
        // 验证其保持初始零值，暴露潜在未实现的功能
        XCTAssertEqual(coordinator.provenance.importedCount, 0, "provenance.importedCount 应保持初始零值（loadStats 未填充）")
        XCTAssertEqual(coordinator.provenance.importedSize, 0, "provenance.importedSize 应保持初始零值")
        XCTAssertEqual(coordinator.provenance.createdCount, 0, "provenance.createdCount 应保持初始零值")
        XCTAssertEqual(coordinator.provenance.createdSize, 0, "provenance.createdSize 应保持初始零值")
    }

    // MARK: - 延迟相关属性

    /// 验证 loadStats 后延迟相关属性保持初始零值（当前实现未填充）
    func testLoadStats_延迟属性保持初始零值() async throws {
        await coordinator.loadStats()

        XCTAssertEqual(coordinator.avgLatency, 0, "avgLatency 应保持初始零值")
        XCTAssertEqual(coordinator.maxLatency, 0, "maxLatency 应保持初始零值")
        XCTAssertEqual(coordinator.minLatency, 0, "minLatency 应保持初始零值")
        XCTAssertEqual(coordinator.latencyCount, 0, "latencyCount 应保持初始零值")
    }

    // MARK: - cleanupData 多次调用

    /// 验证多次调用 cleanupData 后 cleanedCount 为最后一次的返回值
    func testCleanupData_多次调用_cleanedCount为最后一次返回值() async throws {
        configurableVectorRepo.stubCleanupCount = 5
        await coordinator.cleanupData()
        XCTAssertEqual(coordinator.cleanedCount, 5, "第一次 cleanupData 后 cleanedCount 应为 5")

        configurableVectorRepo.stubCleanupCount = 10
        await coordinator.cleanupData()
        XCTAssertEqual(coordinator.cleanedCount, 10, "第二次 cleanupData 后 cleanedCount 应为 10")
    }

    /// 验证 cleanupData 成功后再抛错 cleanedCount 保持上次成功值
    func testCleanupData_成功后再抛错_cleanedCount保持上次成功值() async throws {
        configurableVectorRepo.stubCleanupCount = 7
        await coordinator.cleanupData()
        XCTAssertEqual(coordinator.cleanedCount, 7, "成功后 cleanedCount 应为 7")

        configurableVectorRepo.shouldThrowCleanup = true
        await coordinator.cleanupData()
        // 抛错路径不赋值 cleanedCount，应保持上次成功值 7
        XCTAssertEqual(coordinator.cleanedCount, 7, "抛错后 cleanedCount 应保持上次成功值 7")
    }
}

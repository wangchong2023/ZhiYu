//
//  SystemStatsDeepTestMocks.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：SystemStatsCoordinator 深度补盲测试共享 Mock 基础设施 — 提供可配置的
//            Logger / Haptic / VectorRepository / RAGGovernanceRepository /
//            PageStoreCapabilities / KnowledgeRepository Mock，支持注入异常与精确数据，
//            供 Load / Fetch / Cleanup 三组深度测试复用。
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
func makeSystemStatsTestError(_ description: String) -> NSError {
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

    func addLog(_ entry: LogEntry) {
        addLogCallCount += 1
        lastAction = entry.action
        lastTarget = entry.target
        lastModule = entry.module
    }

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
            throw makeSystemStatsTestError("清理失败")
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
            throw makeSystemStatsTestError("日报查询失败")
        }
        return stubDailyStats
    }
    func fetchMonthlyTokenStats() async throws -> [(month: String, total: Int)] {
        monthlyStatsCallCount += 1
        if shouldThrowMonthlyStats {
            throw makeSystemStatsTestError("月报查询失败")
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
    func createPage(
        title: String,
        pageType: PageType,
        customIcon: String?,
        content: String,
        tags: [String],
        sourceURL: String?,
        rawSnippet: String?,
        fileSize: Int64?,
        sourceType: String?
    ) async throws -> KnowledgePage {
        KnowledgePage(title: title, pageType: pageType, customIcon: customIcon, content: content, tags: tags, sourceURL: sourceURL, rawTextSnippet: rawSnippet, fileSize: fileSize, sourceType: sourceType)
    }
    @discardableResult
    func anyCreatePage(
        title: String,
        pageType: PageType,
        customIcon: String?,
        content: String,
        tags: [String],
        sourceURL: String?,
        rawSnippet: String?,
        fileSize: Int64?,
        sourceType: String?,
        forceDeepScan: Bool
    ) async -> KnowledgePage? {
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
            throw makeSystemStatsTestError("fetchAll 失败")
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
            throw makeSystemStatsTestError("count 失败")
        }
        return stubCount
    }
}

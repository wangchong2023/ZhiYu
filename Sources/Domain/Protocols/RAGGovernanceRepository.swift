//
//  GovernanceRepository.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域层协议定义（Repository、Service、Strategy 等抽象）。
//
import Foundation
import Dependencies
import UFPCore

/// [Domain] RAG 全链路质量治理仓储协议（评估、Token 审计、调用日志）
public protocol RAGGovernanceRepository: Sendable {
    // MARK: - Token 计费 (Usage)
    
    /// 记录 Token 消耗情况
    func logTokenUsage(model: String, promptTokens: Int, completionTokens: Int) async throws
    
    /// 获取指定天数内的 Token 统计数据 (汇总)
    func fetchTokenStats(days: Int) async throws -> TokenStats
    
    /// 获取每日统计详情 (用于图表)
    func fetchDailyAIStats(days: Int) async throws -> [DailyAIStat]
    
    /// 获取月度统计详情
    func fetchMonthlyTokenStats() async throws -> [(month: String, total: Int)]

    // MARK: - 调用日志 (Logs)
    
    /// 记录单次 LLM 调用详情
    func logCall(model: String, promptTokens: Int, completionTokens: Int, latencyMS: Int, status: String) async throws
    
    /// 获取最近的调用日志
    func fetchRecentLogs(limit: Int) async throws -> [LLMCallLog]

    // MARK: - RAG 评估 (Evaluations)
    
    /// 保存 RAG 评估结果
    func saveRAGEvaluation(_ evaluation: RAGEvaluation) async throws
    
    /// 获取最近的评估结果
    func fetchRAGEvaluations(limit: Int) async throws -> [RAGEvaluation]
    
    /// 计算平均评估得分（包含生成质量与引用保真指标）
    func calculateAverageRAGScores(days: Int) async throws -> AverageRAGScores

    // MARK: - 检索快照 (Retrieval Snapshots)

    /// 保存检索快照（评估时记录完整 Top-N 排序结果）
    func saveRetrievalSnapshots(_ snapshots: [RetrievalSnapshot]) async throws

    /// 获取某次评估的检索快照
    func fetchRetrievalSnapshots(evaluationID: Int64) async throws -> [RetrievalSnapshot]

    // MARK: - 相关性标注 (Relevance Judgments)

    /// 保存相关性标注
    func saveRelevanceJudgments(_ judgments: [RelevanceJudgment]) async throws

    // MARK: - 检索质量指标 (Retrieval Metrics)

    /// Hit Rate@K：Top-K 结果中至少命中一个相关文档的查询占比
    func calculateHitRate(days: Int, k: Int) async throws -> Double

    /// MRR (Mean Reciprocal Rank)：首个相关文档排名的倒数均值
    func calculateMRR(days: Int) async throws -> Double

    /// NDCG@K (Normalized Discounted Cumulative Gain)：归一化折损累计增益
    func calculateNDCG(days: Int, k: Int) async throws -> Double

    /// Recall@K：所有相关文档中被 Top-K 检索结果覆盖的比例
    func calculateRecall(days: Int, k: Int) async throws -> Double

    /// F1@K：Precision@K 与 Recall@K 的调和平均
    func calculateF1Score(days: Int, k: Int) async throws -> Double

    /// MAP (Mean Average Precision)：每个查询在各召回位置的精确率均值
    func calculateMAP(days: Int) async throws -> Double

    // MARK: - 性能延迟 (Latency)

    /// 计算指定天数内的检索延迟百分位分布
    func calculateRetrievalLatency(days: Int) async throws -> LatencyPercentiles

    // MARK: - Token 效率 (Efficiency)

    /// 计算指定天数内的 Token 效率与成本摘要
    func calculateTokenEfficiency(days: Int) async throws -> TokenEfficiency

    // MARK: - 用户反馈

    /// 更新评估记录的用户满意度评分（1=差评，2=好评）
    func updateUserRating(evaluationID: Int64, rating: Int) async throws
}

/// Token 统计数据
public struct TokenStats: Sendable, Equatable {
    public let prompt: Int
    public let completion: Int
    public let total: Int

    public init(prompt: Int, completion: Int, total: Int) {
        self.prompt = prompt
        self.completion = completion
        self.total = total
    }
}

/// 每日 AI 统计
public struct DailyAIStat: Sendable, Equatable {
    public let date: String
    public let tokens: Int
    public let requests: Int

    public init(date: String, tokens: Int, requests: Int) {
        self.date = date
        self.tokens = tokens
        self.requests = requests
    }
}

/// 平均 RAG 评分（七维：含幻觉率、引用准确度、答案正确性、上下文充分性）
public struct AverageRAGScores: Sendable, Equatable {
    public let faithfulness: Double
    public let relevance: Double
    public let precision: Double
    public let hallucinationRate: Double
    public let citationAccuracy: Double
    public let answerCorrectness: Double
    public let contextSufficiency: Double

    public init(faithfulness: Double, relevance: Double, precision: Double, hallucinationRate: Double, citationAccuracy: Double, answerCorrectness: Double = 0.0, contextSufficiency: Double = 0.0) {
        self.faithfulness = faithfulness
        self.relevance = relevance
        self.precision = precision
        self.hallucinationRate = hallucinationRate
        self.citationAccuracy = citationAccuracy
        self.answerCorrectness = answerCorrectness
        self.contextSufficiency = contextSufficiency
    }
}

/// 检索延迟百分位分布
public struct LatencyPercentiles: Sendable, Equatable {
    /// 中位延迟（毫秒）
    public let p50: Int
    /// P95 延迟（毫秒）
    public let p95: Int
    /// P99 延迟（毫秒）
    public let p99: Int
    /// 样本数量
    public let sampleCount: Int

    public init(p50: Int, p95: Int, p99: Int, sampleCount: Int) {
        self.p50 = p50
        self.p95 = p95
        self.p99 = p99
        self.sampleCount = sampleCount
    }
}

/// Token 效率与成本摘要
public struct TokenEfficiency: Sendable, Equatable {
    /// 总 Token 消耗
    public let totalTokens: Int
    /// 查询总数
    public let queryCount: Int
    /// 每次查询平均 Token
    public let avgTokensPerQuery: Double
    /// 估算成本（美元，按 GPT-4o 计费）
    public let estimatedCostUSD: Double

    public init(totalTokens: Int, queryCount: Int, avgTokensPerQuery: Double, estimatedCostUSD: Double) {
        self.totalTokens = totalTokens
        self.queryCount = queryCount
        self.avgTokensPerQuery = avgTokensPerQuery
        self.estimatedCostUSD = estimatedCostUSD
    }
}

// MARK: - DependencyKey 注册

/// RAGGovernanceRepository 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum RAGGovernanceRepositoryKey: DependencyKey {
    public static var liveValue: any RAGGovernanceRepository {
        ServiceContainer.shared.resolve((any RAGGovernanceRepository).self)
    }

    public static var testValue: any RAGGovernanceRepository {
        ServiceContainer.shared.resolveOptional((any RAGGovernanceRepository).self) ?? NoOpRAGGovernanceRepository()
    }
}

/// 无操作 RAG 治理仓储（测试/预览占位，DI 未就绪时降级）
public final class NoOpRAGGovernanceRepository: RAGGovernanceRepository, @unchecked Sendable {
    public init() {}
    public func logTokenUsage(model: String, promptTokens: Int, completionTokens: Int) async throws {}
    public func fetchTokenStats(days: Int) async throws -> TokenStats {
        TokenStats(prompt: 0, completion: 0, total: 0)
    }
    public func fetchDailyAIStats(days: Int) async throws -> [DailyAIStat] { [] }
    public func fetchMonthlyTokenStats() async throws -> [(month: String, total: Int)] { [] }
    public func logCall(model: String, promptTokens: Int, completionTokens: Int, latencyMS: Int, status: String) async throws {}
    public func fetchRecentLogs(limit: Int) async throws -> [LLMCallLog] { [] }
    public func saveRAGEvaluation(_ evaluation: RAGEvaluation) async throws {}
    public func fetchRAGEvaluations(limit: Int) async throws -> [RAGEvaluation] { [] }
    public func calculateAverageRAGScores(days: Int) async throws -> AverageRAGScores {
        AverageRAGScores(faithfulness: 0, relevance: 0, precision: 0, hallucinationRate: 0, citationAccuracy: 0)
    }
    public func saveRetrievalSnapshots(_ snapshots: [RetrievalSnapshot]) async throws {}
    public func fetchRetrievalSnapshots(evaluationID: Int64) async throws -> [RetrievalSnapshot] { [] }
    public func saveRelevanceJudgments(_ judgments: [RelevanceJudgment]) async throws {}
    public func calculateHitRate(days: Int, k: Int) async throws -> Double { 0 }
    public func calculateMRR(days: Int) async throws -> Double { 0 }
    public func calculateNDCG(days: Int, k: Int) async throws -> Double { 0 }
    public func calculateRecall(days: Int, k: Int) async throws -> Double { 0 }
    public func calculateF1Score(days: Int, k: Int) async throws -> Double { 0 }
    public func calculateMAP(days: Int) async throws -> Double { 0 }
    public func calculateRetrievalLatency(days: Int) async throws -> LatencyPercentiles {
        LatencyPercentiles(p50: 0, p95: 0, p99: 0, sampleCount: 0)
    }
    public func calculateTokenEfficiency(days: Int) async throws -> TokenEfficiency {
        TokenEfficiency(totalTokens: 0, queryCount: 0, avgTokensPerQuery: 0, estimatedCostUSD: 0)
    }
    public func updateUserRating(evaluationID: Int64, rating: Int) async throws {}
}

extension DependencyValues {
    /// RAG 治理仓储依赖
    public var ragGovernanceRepository: any RAGGovernanceRepository {
        get { self[RAGGovernanceRepositoryKey.self] }
        set { self[RAGGovernanceRepositoryKey.self] = newValue }
    }
}

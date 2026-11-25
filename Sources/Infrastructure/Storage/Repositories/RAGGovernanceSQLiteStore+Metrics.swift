//
//  RAGGovernanceSQLiteStore+Metrics.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层 / RAG 治理指标计算扩展
//  核心职责：承载 RAGGovernanceSQLiteStore 的检索质量指标（Hit@K / MRR / NDCG@K / Recall / F1 / MAP）、
//           延迟百分位、Token 效率成本与用户满意度评分更新逻辑。
//

import Foundation
@preconcurrency import UFPStorage

extension RAGGovernanceSQLiteStore {

    // MARK: - 检索质量指标

    /// 计算 Hit@K — Top-K 检索结果中至少命中 1 条相关结果的比例。
    /// 算法：hit@K = (至少一条相关结果的查询数) / 总查询数。
    func calculateHitRate(days: Int, k: Int) async throws -> Double {
        try await computeMetricAverage(days: days) { eval, db in
            guard let evalID = eval.id else { return nil }
            let snapshots = try self.fetchTopKSnapshots(db: db, evaluationID: evalID, k: k)
            let hasRelevant = try snapshots.contains { snap in
                try self.fetchRelevantJudgment(db: db, sourceID: snap.sourceID) != nil
            }
            return hasRelevant ? 1.0 : 0.0
        }
    }

    /// 计算 MRR (Mean Reciprocal Rank) — 首个相关结果的排名倒数均值。
    /// 算法：MRR = (1/n) * Σ(1 / rank_of_first_relevant)，值域 [0, 1]。
    func calculateMRR(days: Int) async throws -> Double {
        try await computeMetricAverage(days: days) { eval, db in
            guard let evalID = eval.id else { return nil }
            let snapshots = try self.fetchTopKSnapshots(db: db, evaluationID: evalID, k: nil)
            // Bug #36 修复：MRR 应使用实际 rank 字段，而非数组位置 idx+1
            for snap in snapshots where try self.fetchRelevantJudgment(db: db, sourceID: snap.sourceID) != nil {
                return 1.0 / Double(snap.rank)
            }
            return 0.0
        }
    }

    /// 计算归一化折扣累积增益 (NDCG@K)，衡量检索结果排序质量。
    /// 算法：DCG@K = Σ (2^rel_i - 1) / log2(rank_i + 1)，NDCG = DCG / IDCG（理想排序下的最大 DCG）。
    /// NDCG 值域为 [0, 1]，越高表示排序质量越好。
    /// - Parameter days: 统计时间窗口（天数），筛选该时间段内的评估记录
    /// - Parameter k: Top-K 截断深度，只考虑前 K 个检索结果
    /// - Returns: 所有查询 NDCG@K 的均值；无数据时返回 0.0
    func calculateNDCG(days: Int, k: Int) async throws -> Double {
        try await computeMetricAverage(days: days) { eval, db in
            guard let evalID = eval.id else { return nil }
            let snapshots = try self.fetchTopKSnapshots(db: db, evaluationID: evalID, k: k)
            guard !snapshots.isEmpty else { return nil }

            // 收集每个快照对应的相关性等级
            var relevanceLevels: [Int] = []
            for snap in snapshots {
                let judgment = try RelevanceJudgment
                    .filter(RelevanceJudgment.Columns.sourceID == snap.sourceID)
                    .fetchOne(db)
                relevanceLevels.append(judgment?.relevanceLevel ?? 0)
            }

            // DCG@K = Σ (2^rel_i - 1) / log2(rank_i + 1)
            var dcg: Double = 0
            for (idx, snap) in snapshots.enumerated() {
                let rel = relevanceLevels[idx]
                let gain = pow(2.0, Double(rel)) - 1.0
                // Bug #37 修复：DCG discount 应使用实际 rank 字段，而非数组位置 idx+1
                let discount = log2(Double(snap.rank) + 1.0)
                dcg += gain / discount
            }

            // IDCG@K：理想排序（降序）
            let idealLevels = relevanceLevels.sorted(by: >)
            var idcg: Double = 0
            for (idx, rel) in idealLevels.enumerated() {
                let gain = pow(2.0, Double(rel)) - 1.0
                let discount = log2(Double(idx + 1) + 1.0)
                idcg += gain / discount
            }
            guard idcg > 0 else { return nil }
            return dcg / idcg
        }
    }

    func calculateRecall(days: Int, k: Int) async throws -> Double {
        try await computeMetricAverage(days: days) { eval, db in
            guard let evalID = eval.id else { return nil }
            let relevant = try self.fetchRelevantJudgmentsAndSourceIDs(db: db, evaluationID: evalID)
            guard !relevant.judgments.isEmpty else { return nil }
            let snapshots = try self.fetchTopKSnapshots(db: db, evaluationID: evalID, k: k)
            let retrievedRelevant = snapshots.filter { relevant.sourceIDs.contains($0.sourceID) }.count
            return Double(retrievedRelevant) / Double(relevant.judgments.count)
        }
    }

    func calculateF1Score(days: Int, k: Int) async throws -> Double {
        try await computeMetricAverage(days: days) { eval, db in
            guard let evalID = eval.id else { return nil }
            let relevant = try self.fetchRelevantJudgmentsAndSourceIDs(db: db, evaluationID: evalID)
            guard !relevant.judgments.isEmpty else { return nil }
            let topK = try self.fetchTopKSnapshots(db: db, evaluationID: evalID, k: k)
            guard !topK.isEmpty else { return nil }
            let retrievedRelevant = topK.filter { relevant.sourceIDs.contains($0.sourceID) }.count
            let precision = Double(retrievedRelevant) / Double(topK.count)
            let recall = Double(retrievedRelevant) / Double(relevant.judgments.count)
            let denominator = precision + recall
            guard denominator > 0 else { return nil }
            return RAGGovernanceFormula.f1HarmonicCoefficient * precision * recall / denominator
        }
    }

    // MARK: - MAP (Mean Average Precision)

    func calculateMAP(days: Int) async throws -> Double {
        try await computeMetricAverage(days: days) { eval, db in
            guard let evalID = eval.id else { return nil }
            let relevant = try self.fetchRelevantJudgmentsAndSourceIDs(db: db, evaluationID: evalID)
            guard !relevant.judgments.isEmpty else { return nil }
            let totalRelevant = relevant.judgments.count
            let snapshots = try self.fetchTopKSnapshots(db: db, evaluationID: evalID, k: nil)
            guard !snapshots.isEmpty else { return nil }
            var relevantHitCount = 0
            var sumPrecision: Double = 0
            for (idx, snap) in snapshots.enumerated() where relevant.sourceIDs.contains(snap.sourceID) {
                relevantHitCount += 1
                sumPrecision += Double(relevantHitCount) / Double(idx + 1)
            }
            return sumPrecision / Double(totalRelevant)
        }
    }

    // MARK: - 检索延迟百分位

    func calculateRetrievalLatency(days: Int) async throws -> LatencyPercentiles {
        try await readWithCutoff(days: days) { db, cutoff in
            let logs = try LLMCallLog
                .filter(LLMCallLog.Columns.createdAt >= cutoff)
                .order(LLMCallLog.Columns.latencyMS).fetchAll(db)
            let latencies = logs.map(\.latencyMS)
            guard !latencies.isEmpty else { return LatencyPercentiles(p50: 0, p95: 0, p99: 0, sampleCount: 0) }
            let count = latencies.count
            /// nearest-rank 法：rank = ceil(N * p / 100)，索引 = rank - 1
            func percentile(_ p: Double) -> Int {
                let rank = Int((Double(count) * p / RAGGovernanceFormula.percentileBase).rounded(.up))
                return latencies[max(0, min(rank - 1, count - 1))]
            }
            return LatencyPercentiles(p50: percentile(50), p95: percentile(95), p99: percentile(99), sampleCount: count)
        }
    }

    // MARK: - Token 效率与成本

    func calculateTokenEfficiency(days: Int) async throws -> TokenEfficiency {
        try await readWithCutoff(days: days) { db, cutoff in
            let statsRequest = TokenUsage
                .filter(TokenUsage.Columns.createdAt >= cutoff)
                .select(sum(TokenUsage.Columns.totalTokens), sum(TokenUsage.Columns.promptTokens),
                        sum(TokenUsage.Columns.completionTokens), count(TokenUsage.Columns.id))
            guard let row = try Row.fetchOne(db, statsRequest) else {
                return TokenEfficiency(totalTokens: 0, queryCount: 0, avgTokensPerQuery: 0, estimatedCostUSD: 0)
            }
            let totalTokens: Int = row[0] ?? 0
            let promptTokens: Int = row[1] ?? 0
            let completionTokens: Int = row[2] ?? 0
            let queryCount: Int = row[3] ?? 0
            let avgTokensPerQuery = queryCount > 0 ? Double(totalTokens) / Double(queryCount) : 0.0
            let tokensPerMillion: Double = 1_000_000.0
            let promptCost = Double(promptTokens) / tokensPerMillion * AppConfig.AI.pricingPromptPer1M
            let completionCost = Double(completionTokens) / tokensPerMillion * AppConfig.AI.pricingCompletionPer1M
            return TokenEfficiency(totalTokens: totalTokens, queryCount: queryCount,
                                   avgTokensPerQuery: avgTokensPerQuery, estimatedCostUSD: promptCost + completionCost)
        }
    }

    // MARK: - 用户反馈

    /// 更新评估记录的用户满意度评分
    func updateUserRating(evaluationID: Int64, rating: Int) async throws {
        let writer = try await dbWriter
        try await writer.write { db in
            guard var evaluation = try RAGEvaluation.fetchOne(db, key: evaluationID) else { return }
            evaluation.userRating = rating
            try evaluation.update(db)
        }
    }
}

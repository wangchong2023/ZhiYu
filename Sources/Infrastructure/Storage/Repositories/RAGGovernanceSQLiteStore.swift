//
//  RAGGovernanceSQLiteStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：RAG 全链路质量治理 SQLite 存储实现。
//
import Foundation
import UFPStorage

/// [Infra] RAG 全链路质量治理 SQLite 存储
final class RAGGovernanceSQLiteStore: RAGGovernanceRepository, DatabaseWriterProvider, @unchecked Sendable {
    // MARK: - Token 计费 (Usage)

    /// 记录日志TokenUsage
    /// - Parameter model: model
    /// - Parameter promptTokens: promptTokens
    /// - Parameter completionTokens: completionTokens
    func logTokenUsage(model: String, promptTokens: Int, completionTokens: Int) async throws {
        let writer = await dbWriter
        try await writer.write { db in
            var usage = TokenUsage(model: model, promptTokens: promptTokens, completionTokens: completionTokens)
            try usage.insert(db)
        }
    }

    /// 拉取TokenStats
    /// - Parameter days: days
    /// - Returns: 返回值
    func fetchTokenStats(days: Int) async throws -> TokenStats {
        let writer = await dbWriter
        return try await writer.read { db in
            let dateThreshold = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            
            let request = TokenUsage
                .filter(TokenUsage.Columns.createdAt >= dateThreshold)
                .select(
                    sum(TokenUsage.Columns.promptTokens),
                    sum(TokenUsage.Columns.completionTokens),
                    sum(TokenUsage.Columns.totalTokens)
                )
            
            if let row = try Row.fetchOne(db, request) {
                return TokenStats(
                    prompt: row[0] ?? 0,
                    completion: row[1] ?? 0,
                    total: row[2] ?? 0
                )
            }
            return TokenStats(prompt: 0, completion: 0, total: 0)
        }
    }

    /// 拉取DailyAIStats
    /// - Parameter days: days
    /// - Returns: 列表
    func fetchDailyAIStats(days: Int) async throws -> [DailyAIStat] {
        let writer = await dbWriter
        return try await writer.read { db in
            let dateThreshold = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            
            let dayExpr = SQL("strftime('%Y-%m-%d', \(TokenUsage.Columns.createdAt))")
            let request = TokenUsage
                .filter(TokenUsage.Columns.createdAt >= dateThreshold)
                .select(
                    dayExpr.forKey("day"),
                    sum(TokenUsage.Columns.totalTokens).forKey("tokens"),
                    count(TokenUsage.Columns.id).forKey("requests")
                )
                .group(dayExpr)
                .order(dayExpr)
            
            let rows = try Row.fetchAll(db, request)
            
            return rows.map { row in
                DailyAIStat(
                    date: row["day"] ?? "",
                    tokens: row["tokens"] ?? 0,
                    requests: row["requests"] ?? 0
                )
            }
        }
    }

    /// 拉取MonthlyTokenStats
    /// - Returns: 列表
    func fetchMonthlyTokenStats() async throws -> [(month: String, total: Int)] {
        let writer = await dbWriter
        return try await writer.read { db in
            let monthExpr = SQL("strftime('%Y-%m', \(TokenUsage.Columns.createdAt))")
            let request = TokenUsage
                .select(
                    monthExpr.forKey("month"),
                    sum(TokenUsage.Columns.totalTokens).forKey("total")
                )
                .group(monthExpr)
                .order(monthExpr)
            
            let rows = try Row.fetchAll(db, request)
            
            return rows.map { row in (
                month: row["month"] ?? "",
                total: row["total"] ?? 0
            ) }
        }
    }

    // MARK: - 调用日志 (Logs)

    /// 记录日志Call
    /// - Parameter model: model
    /// - Parameter promptTokens: promptTokens
    /// - Parameter completionTokens: completionTokens
    /// - Parameter latencyMS: latencyMS
    /// - Parameter status: status
    func logCall(model: String, promptTokens: Int, completionTokens: Int, latencyMS: Int, status: String) async throws {
        let writer = await dbWriter
        try await writer.write { db in
            var log = LLMCallLog(
                model: model,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                latencyMS: latencyMS,
                status: status
            )
            try log.insert(db)
        }
    }

    /// 拉取RecentLogs
    /// - Parameter limit: limit
    /// - Returns: 列表
    func fetchRecentLogs(limit: Int) async throws -> [LLMCallLog] {
        let writer = await dbWriter
        return try await writer.read { db in
            try LLMCallLog
                .order(LLMCallLog.Columns.createdAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    // MARK: - RAG 评估 (Evaluations)

    /// 保存RAGEvaluation，返回带 id 的已持久化模型
    /// - Parameter evaluation: evaluation
    /// 保存RAGEvaluation
    /// - Parameter evaluation: evaluation
    func saveRAGEvaluation(_ evaluation: RAGEvaluation) async throws {
        let writer = await dbWriter
        try await writer.write { db in
            var mutableEvaluation = evaluation
            try mutableEvaluation.insert(db)
        }
    }

    /// 拉取RAGEvaluations
    /// - Parameter limit: limit
    /// - Returns: 列表
    func fetchRAGEvaluations(limit: Int) async throws -> [RAGEvaluation] {
        let writer = await dbWriter
        return try await writer.read { db in
            try RAGEvaluation
                .order(RAGEvaluation.Columns.createdAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// 计算AverageRAGScores（含幻觉率、引用准确度与答案正确性）
    /// - Parameter days: days
    /// - Returns: 六维均值元组
    func calculateAverageRAGScores(days: Int) async throws -> AverageRAGScores {
        let writer = await dbWriter
        return try await writer.read { db in
            let dateThreshold = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

            let request = RAGEvaluation
                .filter(RAGEvaluation.Columns.createdAt >= dateThreshold)
                .select(
                    average(RAGEvaluation.Columns.faithfulness),
                    average(RAGEvaluation.Columns.relevance),
                    average(RAGEvaluation.Columns.precision),
                    average(RAGEvaluation.Columns.hallucinationRate),
                    average(RAGEvaluation.Columns.citationAccuracy),
                    average(RAGEvaluation.Columns.answerCorrectness),
                    average(RAGEvaluation.Columns.contextSufficiency)
                )

            if let row = try Row.fetchOne(db, request) {
                return AverageRAGScores(
                    faithfulness: row[0] ?? 0.0,
                    relevance: row[1] ?? 0.0,
                    precision: row[2] ?? 0.0,
                    hallucinationRate: row[3] ?? 0.0,
                    citationAccuracy: row[4] ?? 0.0,
                    answerCorrectness: row[5] ?? 0.0,
                    contextSufficiency: row[6] ?? 0.0
                )
            }
            return AverageRAGScores(faithfulness: 0.0, relevance: 0.0, precision: 0.0, hallucinationRate: 0.0, citationAccuracy: 0.0, answerCorrectness: 0.0, contextSufficiency: 0.0)
        }
    }

    // MARK: - 检索快照 (Retrieval Snapshots)

    func saveRetrievalSnapshots(_ snapshots: [RetrievalSnapshot]) async throws {
        guard !snapshots.isEmpty else { return }
        let writer = await dbWriter
        try await writer.write { db in
            for var s in snapshots {
                try s.insert(db)
            }
        }
    }

    func fetchRetrievalSnapshots(evaluationID: Int64) async throws -> [RetrievalSnapshot] {
        let writer = await dbWriter
        return try await writer.read { db in
            try RetrievalSnapshot
                .filter(RetrievalSnapshot.Columns.evaluationID == evaluationID)
                .order(RetrievalSnapshot.Columns.rank)
                .fetchAll(db)
        }
    }

    // MARK: - 相关性标注 (Relevance Judgments)

    func saveRelevanceJudgments(_ judgments: [RelevanceJudgment]) async throws {
        guard !judgments.isEmpty else { return }
        let writer = await dbWriter
        try await writer.write { db in
            for var j in judgments {
                // 同 query_hash + source_id 组合去重覆盖
                try j.upsert(db)
            }
        }
    }

    // MARK: - 检索质量指标

    /// 计算 Hit@K — Top-K 检索结果中至少命中 1 条相关结果的比例。
    /// 算法：hit@K = (至少一条相关结果的查询数) / 总查询数。
    func calculateHitRate(days: Int, k: Int) async throws -> Double {
        let writer = await dbWriter
        return try await writer.read { db in
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

            // 获取时间范围内的所有评估
            let evals = try RAGEvaluation
                .filter(RAGEvaluation.Columns.createdAt >= cutoff)
                .fetchAll(db)

            guard !evals.isEmpty else { return 0.0 }

            var hitCount = 0
            for eval in evals {
                guard let evalID = eval.id else { continue }
                // 获取该评估的 Top-K 快照
                let snapshots = try RetrievalSnapshot
                    .filter(RetrievalSnapshot.Columns.evaluationID == evalID && RetrievalSnapshot.Columns.rank <= k)
                    .order(RetrievalSnapshot.Columns.rank)
                    .fetchAll(db)

                // 检查快照中是否有相关结果（被标注为 ≥1）
                let hasRelevant = try snapshots.contains { snap in
                    let judgment = try RelevanceJudgment
                        .filter(RelevanceJudgment.Columns.sourceID == snap.sourceID && RelevanceJudgment.Columns.relevanceLevel >= 1)
                        .fetchOne(db)
                    return judgment != nil
                }
                if hasRelevant { hitCount += 1 }
            }
            return Double(hitCount) / Double(evals.count)
        }
    }

    /// 计算 MRR (Mean Reciprocal Rank) — 首个相关结果的排名倒数均值。
    /// 算法：MRR = (1/n) * Σ(1 / rank_of_first_relevant)，值域 [0, 1]。
    func calculateMRR(days: Int) async throws -> Double {
        let writer = await dbWriter
        return try await writer.read { db in
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let evals = try RAGEvaluation
                .filter(RAGEvaluation.Columns.createdAt >= cutoff)
                .fetchAll(db)

            guard !evals.isEmpty else { return 0.0 }

            var totalRR: Double = 0
            var queryCount = 0
            for eval in evals {
                guard let evalID = eval.id else { continue }
                let snapshots = try RetrievalSnapshot
                    .filter(RetrievalSnapshot.Columns.evaluationID == evalID)
                    .order(RetrievalSnapshot.Columns.rank)
                    .fetchAll(db)

                for (idx, snap) in snapshots.enumerated() {
                    let judgment = try RelevanceJudgment
                        .filter(RelevanceJudgment.Columns.sourceID == snap.sourceID && RelevanceJudgment.Columns.relevanceLevel >= 1)
                        .fetchOne(db)
                    if judgment != nil {
                        totalRR += 1.0 / Double(idx + 1)  // rank = idx + 1
                        break
                    }
                }
                queryCount += 1
            }
            return queryCount > 0 ? totalRR / Double(queryCount) : 0.0
        }
    }

    /// 计算归一化折扣累积增益 (NDCG@K)，衡量检索结果排序质量。
    /// 算法：DCG@K = Σ (2^rel_i - 1) / log2(rank_i + 1)，NDCG = DCG / IDCG（理想排序下的最大 DCG）。
    /// NDCG 值域为 [0, 1]，越高表示排序质量越好。
    /// - Parameter days: 统计时间窗口（天数），筛选该时间段内的评估记录
    /// - Parameter k: Top-K 截断深度，只考虑前 K 个检索结果
    /// - Returns: 所有查询 NDCG@K 的均值；无数据时返回 0.0
    func calculateNDCG(days: Int, k: Int) async throws -> Double {
        let writer = await dbWriter
        return try await writer.read { db in
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let evals = try RAGEvaluation
                .filter(RAGEvaluation.Columns.createdAt >= cutoff)
                .fetchAll(db)

            guard !evals.isEmpty else { return 0.0 }

            var totalNDCG: Double = 0
            var queryCount = 0
            for eval in evals {
                guard let evalID = eval.id else { continue }
                let snapshots = try RetrievalSnapshot
                    .filter(RetrievalSnapshot.Columns.evaluationID == evalID && RetrievalSnapshot.Columns.rank <= k)
                    .order(RetrievalSnapshot.Columns.rank)
                    .fetchAll(db)

                guard !snapshots.isEmpty else { continue }

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
                for (idx, rel) in relevanceLevels.enumerated() {
                    let gain = pow(2.0, Double(rel)) - 1.0
                    let discount = log2(Double(idx + 1) + 1.0)  // rank = idx + 1
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

                if idcg > 0 {
                    totalNDCG += dcg / idcg
                    queryCount += 1
                }
            }
            return queryCount > 0 ? totalNDCG / Double(queryCount) : 0.0
        }
    }

    func calculateRecall(days: Int, k: Int) async throws -> Double {
        let writer = await dbWriter
        return try await writer.read { db in
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let evals = try RAGEvaluation.filter(RAGEvaluation.Columns.createdAt >= cutoff).fetchAll(db)
            guard !evals.isEmpty else { return 0.0 }
            var totalRecall: Double = 0
            var queryCount = 0
            for eval in evals {
                guard let evalID = eval.id else { continue }
                let allRelevant = try RelevanceJudgment
                    .filter(RelevanceJudgment.Columns.evaluationID == evalID && RelevanceJudgment.Columns.relevanceLevel >= 1)
                    .fetchAll(db)
                guard !allRelevant.isEmpty else { continue }
                let relevantSourceIDs = Set(allRelevant.map(\.sourceID))
                let snapshots = try RetrievalSnapshot
                    .filter(RetrievalSnapshot.Columns.evaluationID == evalID && RetrievalSnapshot.Columns.rank <= k)
                    .order(RetrievalSnapshot.Columns.rank).fetchAll(db)
                let retrievedRelevant = snapshots.filter { relevantSourceIDs.contains($0.sourceID) }.count
                totalRecall += Double(retrievedRelevant) / Double(allRelevant.count)
                queryCount += 1
            }
            return queryCount > 0 ? totalRecall / Double(queryCount) : 0.0
        }
    }

    func calculateF1Score(days: Int, k: Int) async throws -> Double {
        let writer = await dbWriter
        return try await writer.read { db in
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let evals = try RAGEvaluation.filter(RAGEvaluation.Columns.createdAt >= cutoff).fetchAll(db)
            guard !evals.isEmpty else { return 0.0 }
            var totalF1: Double = 0
            var queryCount = 0
            for eval in evals {
                guard let evalID = eval.id else { continue }
                let allRelevant = try RelevanceJudgment
                    .filter(RelevanceJudgment.Columns.evaluationID == evalID && RelevanceJudgment.Columns.relevanceLevel >= 1)
                    .fetchAll(db)
                guard !allRelevant.isEmpty else { continue }
                let relevantSourceIDs = Set(allRelevant.map(\.sourceID))
                let topK = try RetrievalSnapshot
                    .filter(RetrievalSnapshot.Columns.evaluationID == evalID && RetrievalSnapshot.Columns.rank <= k)
                    .order(RetrievalSnapshot.Columns.rank).fetchAll(db)
                guard !topK.isEmpty else { continue }
                let retrievedRelevant = topK.filter { relevantSourceIDs.contains($0.sourceID) }.count
                let precision = Double(retrievedRelevant) / Double(topK.count)
                let recall = Double(retrievedRelevant) / Double(allRelevant.count)
                let denominator = precision + recall
                guard denominator > 0 else { continue }
                totalF1 += 2.0 * precision * recall / denominator
                queryCount += 1
            }
            return queryCount > 0 ? totalF1 / Double(queryCount) : 0.0
        }
    }

    // MARK: - MAP (Mean Average Precision)

    func calculateMAP(days: Int) async throws -> Double {
        let writer = await dbWriter
        return try await writer.read { db in
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let evals = try RAGEvaluation.filter(RAGEvaluation.Columns.createdAt >= cutoff).fetchAll(db)
            guard !evals.isEmpty else { return 0.0 }
            var totalAP: Double = 0
            var queryCount = 0
            for eval in evals {
                guard let evalID = eval.id else { continue }
                let allRelevant = try RelevanceJudgment
                    .filter(RelevanceJudgment.Columns.evaluationID == evalID && RelevanceJudgment.Columns.relevanceLevel >= 1)
                    .fetchAll(db)
                guard !allRelevant.isEmpty else { continue }
                let relevantSet = Set(allRelevant.map(\.sourceID))
                let totalRelevant = allRelevant.count
                let snapshots = try RetrievalSnapshot
                    .filter(RetrievalSnapshot.Columns.evaluationID == evalID)
                    .order(RetrievalSnapshot.Columns.rank).fetchAll(db)
                guard !snapshots.isEmpty else { continue }
                var relevantHitCount = 0
                var sumPrecision: Double = 0
                for (idx, snap) in snapshots.enumerated() where relevantSet.contains(snap.sourceID) {
                    relevantHitCount += 1
                    sumPrecision += Double(relevantHitCount) / Double(idx + 1)
                }
                totalAP += sumPrecision / Double(totalRelevant)
                queryCount += 1
            }
            return queryCount > 0 ? totalAP / Double(queryCount) : 0.0
        }
    }

    // MARK: - 检索延迟百分位

    func calculateRetrievalLatency(days: Int) async throws -> LatencyPercentiles {
        let writer = await dbWriter
        return try await writer.read { db in
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let logs = try LLMCallLog
                .filter(LLMCallLog.Columns.createdAt >= cutoff)
                .order(LLMCallLog.Columns.latencyMS).fetchAll(db)
            let latencies = logs.map(\.latencyMS)
            guard !latencies.isEmpty else { return LatencyPercentiles(p50: 0, p95: 0, p99: 0, sampleCount: 0) }
            let count = latencies.count
            /// nearest-rank 法：rank = ceil(N * p / 100)，索引 = rank - 1
            func percentile(_ p: Double) -> Int {
                let rank = Int((Double(count) * p / 100.0).rounded(.up))
                return latencies[max(0, min(rank - 1, count - 1))]
            }
            return LatencyPercentiles(p50: percentile(50), p95: percentile(95), p99: percentile(99), sampleCount: count)
        }
    }

    // MARK: - Token 效率与成本

    func calculateTokenEfficiency(days: Int) async throws -> TokenEfficiency {
        let writer = await dbWriter
        return try await writer.read { db in
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
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
            let promptCost = Double(promptTokens) / 1_000_000.0 * AppConfig.AI.pricingPromptPer1M
            let completionCost = Double(completionTokens) / 1_000_000.0 * AppConfig.AI.pricingCompletionPer1M
            return TokenEfficiency(totalTokens: totalTokens, queryCount: queryCount,
                                   avgTokensPerQuery: avgTokensPerQuery, estimatedCostUSD: promptCost + completionCost)
        }
    }

    // MARK: - 用户反馈

    /// 更新评估记录的用户满意度评分
    func updateUserRating(evaluationID: Int64, rating: Int) async throws {
        let writer = await dbWriter
        try await writer.write { db in
            guard var evaluation = try RAGEvaluation.fetchOne(db, key: evaluationID) else { return }
            evaluation.userRating = rating
            try evaluation.update(db)
        }
    }
}

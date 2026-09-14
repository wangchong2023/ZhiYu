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

/// RAG 治理统计公式常量
private enum RAGGovernanceFormula {
    /// F1 分数调和平均系数：F1 = 2 * P * R / (P + R)
    static let f1HarmonicCoefficient: Double = 2.0
    /// 百分位换算基数：rank = ceil(N * p / 100)
    static let percentileBase: Double = 100.0
}

/// [Infra] RAG 全链路质量治理 SQLite 存储
final class RAGGovernanceSQLiteStore: RAGGovernanceRepository, DatabaseWriterProvider, @unchecked Sendable {
    // MARK: - 私有辅助

    /// 计算截止日期：当前时间往前推 days 天
    private func cutoffDate(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    /// 计算 Token 统计的日期阈值：days ≤ 0 时取当天 0 点，否则取 days 天前。
    private func tokenStatsDateThreshold(days: Int) -> Date {
        let calendar = Calendar.current
        if days <= 0 {
            return calendar.startOfDay(for: Date())
        }
        return calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    /// 获取时间范围内的所有 RAG 评估记录，空范围返回 nil
    private func fetchEvaluations(db: Database, days: Int) throws -> [RAGEvaluation]? {
        let cutoff = cutoffDate(days: days)
        let evals = try RAGEvaluation
            .filter(RAGEvaluation.Columns.createdAt >= cutoff)
            .fetchAll(db)
        return evals.isEmpty ? nil : evals
    }

    /// 获取指定评估的 Top-K 检索快照（按 rank 升序）。
    /// - Parameters:
    ///   - db: 数据库连接
    ///   - evaluationID: 评估 ID
    ///   - k: Top-K 截断深度，nil 表示不截断
    /// - Returns: 检索快照列表
    private func fetchTopKSnapshots(db: Database, evaluationID: Int64, k: Int?) throws -> [RetrievalSnapshot] {
        var request = RetrievalSnapshot
            .filter(RetrievalSnapshot.Columns.evaluationID == evaluationID)
            .order(RetrievalSnapshot.Columns.rank)
        if let k = k {
            request = request.limit(k)
        }
        return try request.fetchAll(db)
    }

    /// 查询指定 sourceID 的相关性判定（relevanceLevel >= 1 视为相关），消除 Hit@K 与 MRR 中的重复查询样板。
    /// - Parameters:
    ///   - db: 数据库连接
    ///   - sourceID: 检索来源 ID
    /// - Returns: 相关性判定记录（nil 表示无判定或不相关）
    private func fetchRelevantJudgment(db: Database, sourceID: String) throws -> RelevanceJudgment? {
        try RelevanceJudgment
            .filter(RelevanceJudgment.Columns.sourceID == sourceID && RelevanceJudgment.Columns.relevanceLevel >= 1)
            .fetchOne(db)
    }

    /// 在数据库读事务中执行指定查询，统一 cutoff 日期计算与 dbWriter 解析样板。
    /// - Parameters:
    ///   - days: 统计时间窗口（天数）
    ///   - body: 数据库读事务闭包，接收 db 和 cutoff 日期
    /// - Returns: 闭包返回值
    private func readWithCutoff<T>(days: Int, _ body: (Database, Date) throws -> T) async throws -> T {
        let writer = try await dbWriter
        return try await writer.read { db in
            try body(db, cutoffDate(days: days))
        }
    }

    /// 获取指定评估中相关性等级 ≥ 1 的所有标注（相关结果集）。
    /// - Parameters:
    ///   - db: 当前数据库连接
    ///   - evaluationID: 评估记录 ID
    /// - Returns: 相关性标注数组
    private func fetchRelevantJudgments(db: Database, evaluationID: Int64) throws -> [RelevanceJudgment] {
        try RelevanceJudgment
            .filter(RelevanceJudgment.Columns.evaluationID == evaluationID && RelevanceJudgment.Columns.relevanceLevel >= 1)
            .fetchAll(db)
    }

    /// 一次性获取指定评估的相关标注数组与 sourceID 集合，消除 Recall/F1/MAP 中
    /// 重复的 `fetchRelevantJudgments + Set(map(\.sourceID))` 双查询样板。
    /// - Parameters:
    ///   - db: 当前数据库连接
    ///   - evaluationID: 评估记录 ID
    /// - Returns: (相关标注数组, sourceID 集合)
    private func fetchRelevantJudgmentsAndSourceIDs(
        db: Database, evaluationID: Int64
    ) throws -> (judgments: [RelevanceJudgment], sourceIDs: Set<String>) {
        let judgments = try fetchRelevantJudgments(db: db, evaluationID: evaluationID)
        return (judgments, Set(judgments.map(\.sourceID)))
    }

    /// 计算所有评估的指标均值；无有效查询时返回 0.0。
    /// - Parameters:
    ///   - evals: 评估记录数组
    ///   - db: 当前数据库连接
    ///   - metric: 单次评估指标计算闭包（返回指标值或 nil 表示跳过）
    /// - Returns: 指标均值
    private func averageMetric(
        evals: [RAGEvaluation],
        db: Database,
        metric: (RAGEvaluation, Database) throws -> Double?
    ) rethrows -> Double {
        var total: Double = 0
        var queryCount = 0
        for eval in evals {
            guard let value = try metric(eval, db) else { continue }
            total += value
            queryCount += 1
        }
        return queryCount > 0 ? total / Double(queryCount) : 0.0
    }

    /// 在数据库读事务中按时间窗口计算指标均值（消除 calculateMRR/NDCG/Recall/F1/MAP 的前段样板重复）。
    private func computeMetricAverage(
        days: Int,
        metric: (RAGEvaluation, Database) throws -> Double?
    ) async throws -> Double {
        let writer = try await dbWriter
        return try await writer.read { db in
            guard let evals = try fetchEvaluations(db: db, days: days) else { return 0.0 }
            return try averageMetric(eval: evals, db: db, metric: metric)
        }
    }

    // MARK: - Token 计费 (Usage)

    /// 记录日志TokenUsage
    /// - Parameter model: model
    /// - Parameter promptTokens: promptTokens
    /// - Parameter completionTokens: completionTokens
    func logTokenUsage(model: String, promptTokens: Int, completionTokens: Int) async throws {
        let writer = try await dbWriter
        try await writer.write { db in
            var usage = TokenUsage(model: model, promptTokens: promptTokens, completionTokens: completionTokens)
            try usage.insert(db)
        }
    }

    /// 拉取TokenStats
    /// - Parameter days: days
    /// - Returns: 返回值
    func fetchTokenStats(days: Int) async throws -> TokenStats {
        let writer = try await dbWriter
        return try await writer.read { db in
            let dateThreshold = tokenStatsDateThreshold(days: days)

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
        let writer = try await dbWriter
        return try await writer.read { db in
            let dateThreshold = tokenStatsDateThreshold(days: days)
            
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
        let writer = try await dbWriter
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
        let writer = try await dbWriter
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
        let writer = try await dbWriter
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
        let writer = try await dbWriter
        try await writer.write { db in
            var mutableEvaluation = evaluation
            try mutableEvaluation.insert(db)
        }
    }

    /// 拉取RAGEvaluations
    /// - Parameter limit: limit
    /// - Returns: 列表
    func fetchRAGEvaluations(limit: Int) async throws -> [RAGEvaluation] {
        let writer = try await dbWriter
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
        let writer = try await dbWriter
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
        let writer = try await dbWriter
        try await writer.write { db in
            for var s in snapshots {
                try s.insert(db)
            }
        }
    }

    func fetchRetrievalSnapshots(evaluationID: Int64) async throws -> [RetrievalSnapshot] {
        let writer = try await dbWriter
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
        let writer = try await dbWriter
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
        try await computeMetricAverage(days: days) { eval, db in
            guard let evalID = eval.id else { return nil }
            let snapshots = try fetchTopKSnapshots(db: db, evaluationID: evalID, k: k)
            let hasRelevant = try snapshots.contains { snap in
                try fetchRelevantJudgment(db: db, sourceID: snap.sourceID) != nil
            }
            return hasRelevant ? 1.0 : 0.0
        }
    }

    /// 计算 MRR (Mean Reciprocal Rank) — 首个相关结果的排名倒数均值。
    /// 算法：MRR = (1/n) * Σ(1 / rank_of_first_relevant)，值域 [0, 1]。
    func calculateMRR(days: Int) async throws -> Double {
        try await computeMetricAverage(days: days) { eval, db in
            guard let evalID = eval.id else { return nil }
            let snapshots = try fetchTopKSnapshots(db: db, evaluationID: evalID, k: nil)
            // Bug #36 修复：MRR 应使用实际 rank 字段，而非数组位置 idx+1
            for snap in snapshots where try fetchRelevantJudgment(db: db, sourceID: snap.sourceID) != nil {
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
            let snapshots = try fetchTopKSnapshots(db: db, evaluationID: evalID, k: k)
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
            let relevant = try fetchRelevantJudgmentsAndSourceIDs(db: db, evaluationID: evalID)
            guard !relevant.judgments.isEmpty else { return nil }
            let snapshots = try fetchTopKSnapshots(db: db, evaluationID: evalID, k: k)
            let retrievedRelevant = snapshots.filter { relevant.sourceIDs.contains($0.sourceID) }.count
            return Double(retrievedRelevant) / Double(relevant.judgments.count)
        }
    }

    func calculateF1Score(days: Int, k: Int) async throws -> Double {
        try await computeMetricAverage(days: days) { eval, db in
            guard let evalID = eval.id else { return nil }
            let relevant = try fetchRelevantJudgmentsAndSourceIDs(db: db, evaluationID: evalID)
            guard !relevant.judgments.isEmpty else { return nil }
            let topK = try fetchTopKSnapshots(db: db, evaluationID: evalID, k: k)
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
            let relevant = try fetchRelevantJudgmentsAndSourceIDs(db: db, evaluationID: evalID)
            guard !relevant.judgments.isEmpty else { return nil }
            let totalRelevant = relevant.judgments.count
            let snapshots = try fetchTopKSnapshots(db: db, evaluationID: evalID, k: nil)
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
            let promptCost = Double(promptTokens) / 1_000_000.0 * AppConfig.AI.pricingPromptPer1M
            let completionCost = Double(completionTokens) / 1_000_000.0 * AppConfig.AI.pricingCompletionPer1M
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

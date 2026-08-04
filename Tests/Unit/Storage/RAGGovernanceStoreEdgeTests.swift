//
//  RAGGovernanceStoreEdgeTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 RAGGovernanceSQLiteStore 的 Token 计费、调用日志、RAG 评估、
//           检索质量指标（Hit@K/MRR/NDCG/Recall/F1/MAP）边界条件与算法正确性。
//

import XCTest
import UFPStorage
@testable import ZhiYu

final class RAGGovernanceStoreEdgeTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var store: RAGGovernanceSQLiteStore!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        try await DatabaseManager.shared.setupForTesting(with: dbQueue)
        // RAGGovernanceSQLiteStore 使用动态属性从 DatabaseManager.shared.dbWriter 获取
        store = RAGGovernanceSQLiteStore()
    }

    override func tearDownWithError() throws {
        store = nil
        dbQueue = nil
    }

    // MARK: - Token 计费 (Usage)

    /// 验证：logTokenUsage 后 fetchTokenStats 正确聚合。
    func testLogAndFetchTokenStats() async throws {
        try await store.logTokenUsage(model: "gpt-4", promptTokens: 100, completionTokens: 50)
        try await store.logTokenUsage(model: "gpt-4", promptTokens: 200, completionTokens: 100)

        let stats = try await store.fetchTokenStats(days: 7)
        XCTAssertEqual(stats.prompt, 300, "promptTokens 应聚合")
        XCTAssertEqual(stats.completion, 150, "completionTokens 应聚合")
        XCTAssertEqual(stats.total, 450, "totalTokens 应聚合")
    }

    /// 验证：fetchTokenStats 空数据返回全 0。
    func testFetchTokenStatsEmpty() async throws {
        let stats = try await store.fetchTokenStats(days: 7)
        XCTAssertEqual(stats.prompt, 0)
        XCTAssertEqual(stats.completion, 0)
        XCTAssertEqual(stats.total, 0)
    }

    /// 验证：fetchTokenStats days=0 仅返回当天的数据（边界）。
    func testFetchTokenStatsDaysZero() async throws {
        try await store.logTokenUsage(model: "gpt-4", promptTokens: 100, completionTokens: 50)

        let stats = try await store.fetchTokenStats(days: 0)
        // days=0 时 dateThreshold = now，刚插入的记录 createdAt ≈ now，应被包含
        XCTAssertGreaterThanOrEqual(stats.total, 150, "days=0 应包含当天数据")
    }

    /// 验证：fetchDailyAIStats 按天分组返回。
    func testFetchDailyAIStats() async throws {
        try await store.logTokenUsage(model: "gpt-4", promptTokens: 100, completionTokens: 50)
        try await store.logTokenUsage(model: "gpt-4", promptTokens: 200, completionTokens: 100)

        let daily = try await store.fetchDailyAIStats(days: 7)
        XCTAssertEqual(daily.count, 1, "同一天应合并为一条")
        XCTAssertEqual(daily.first?.tokens, 450)
        XCTAssertEqual(daily.first?.requests, 2)
    }

    /// 验证：fetchMonthlyTokenStats 按月分组返回。
    func testFetchMonthlyTokenStats() async throws {
        try await store.logTokenUsage(model: "gpt-4", promptTokens: 100, completionTokens: 50)

        let monthly = try await store.fetchMonthlyTokenStats()
        XCTAssertFalse(monthly.isEmpty, "应有当月数据")
        XCTAssertGreaterThanOrEqual(monthly.first?.total ?? 0, 150)
    }

    // MARK: - 调用日志 (Logs)

    /// 验证：logCall 后 fetchRecentLogs 按 createdAt 降序返回。
    func testLogAndFetchRecentLogs() async throws {
        try await store.logCall(model: "gpt-4", promptTokens: 10, completionTokens: 5, latencyMS: 100, status: "success")
        try await Task.sleep(nanoseconds: 50_000_000)
        try await store.logCall(model: "gpt-4", promptTokens: 20, completionTokens: 10, latencyMS: 200, status: "error")

        let logs = try await store.fetchRecentLogs(limit: 10)
        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(logs.first?.latencyMS, 200, "最新的应排在前面")
        XCTAssertEqual(logs.first?.status, "error")
    }

    /// 验证：fetchRecentLogs limit=0 返回空。
    func testFetchRecentLogsLimitZero() async throws {
        try await store.logCall(model: "gpt-4", promptTokens: 10, completionTokens: 5, latencyMS: 100, status: "success")

        let logs = try await store.fetchRecentLogs(limit: 0)
        XCTAssertTrue(logs.isEmpty, "limit=0 应返回空")
    }

    /// 验证：fetchRecentLogs limit 超过记录数返回全部。
    func testFetchRecentLogsLimitExceeds() async throws {
        try await store.logCall(model: "gpt-4", promptTokens: 10, completionTokens: 5, latencyMS: 100, status: "success")

        let logs = try await store.fetchRecentLogs(limit: 100)
        XCTAssertEqual(logs.count, 1)
    }

    // MARK: - RAG 评估 (Evaluations)

    /// 验证：saveRAGEvaluation 后 fetchRAGEvaluations 按 createdAt 降序返回。
    func testSaveAndFetchRAGEvaluations() async throws {
        let eval1 = RAGEvaluation(
            query: "什么是 RAG",
            answer: "检索增强生成",
            faithfulness: 0.9,
            relevance: 0.8,
            precision: 0.7,
            evaluatorModel: "gpt-4"
        )
        try await store.saveRAGEvaluation(eval1)
        try await Task.sleep(nanoseconds: 50_000_000)
        let eval2 = RAGEvaluation(
            query: "什么是 LLM",
            answer: "大语言模型",
            faithfulness: 0.95,
            relevance: 0.85,
            precision: 0.75,
            evaluatorModel: "gpt-4"
        )
        try await store.saveRAGEvaluation(eval2)

        let evals = try await store.fetchRAGEvaluations(limit: 10)
        XCTAssertEqual(evals.count, 2)
        XCTAssertEqual(evals.first?.query, "什么是 LLM", "最新的应排在前面")
    }

    /// 验证：fetchRAGEvaluations limit=0 返回空。
    func testFetchRAGEvaluationsLimitZero() async throws {
        let eval = RAGEvaluation(
            query: "test",
            answer: "test",
            faithfulness: 0.9,
            relevance: 0.8,
            precision: 0.7,
            evaluatorModel: "gpt-4"
        )
        try await store.saveRAGEvaluation(eval)

        let evals = try await store.fetchRAGEvaluations(limit: 0)
        XCTAssertTrue(evals.isEmpty, "limit=0 应返回空")
    }

    /// 验证：calculateAverageRAGScores 空数据返回全 0。
    func testCalculateAverageRAGScoresEmpty() async throws {
        let scores = try await store.calculateAverageRAGScores(days: 7)
        XCTAssertEqual(scores.faithfulness, 0.0)
        XCTAssertEqual(scores.relevance, 0.0)
        XCTAssertEqual(scores.precision, 0.0)
        XCTAssertEqual(scores.hallucinationRate, 0.0)
        XCTAssertEqual(scores.citationAccuracy, 0.0)
        XCTAssertEqual(scores.answerCorrectness, 0.0)
        XCTAssertEqual(scores.contextSufficiency, 0.0)
    }

    /// 验证：calculateAverageRAGScores 正确计算平均值。
    func testCalculateAverageRAGScores() async throws {
        let eval1 = RAGEvaluation(
            query: "q1", answer: "a1",
            faithfulness: 0.8, relevance: 0.6, precision: 0.4,
            hallucinationRate: 0.1, citationAccuracy: 0.9,
            answerCorrectness: 0.7, contextSufficiency: 0.5,
            evaluatorModel: "gpt-4"
        )
        let eval2 = RAGEvaluation(
            query: "q2", answer: "a2",
            faithfulness: 0.9, relevance: 0.7, precision: 0.5,
            hallucinationRate: 0.2, citationAccuracy: 0.8,
            answerCorrectness: 0.8, contextSufficiency: 0.6,
            evaluatorModel: "gpt-4"
        )
        try await store.saveRAGEvaluation(eval1)
        try await store.saveRAGEvaluation(eval2)

        let scores = try await store.calculateAverageRAGScores(days: 7)
        XCTAssertEqual(scores.faithfulness, 0.85, accuracy: 0.001)
        XCTAssertEqual(scores.relevance, 0.65, accuracy: 0.001)
        XCTAssertEqual(scores.precision, 0.45, accuracy: 0.001)
        XCTAssertEqual(scores.hallucinationRate, 0.15, accuracy: 0.001)
        XCTAssertEqual(scores.citationAccuracy, 0.85, accuracy: 0.001)
        XCTAssertEqual(scores.answerCorrectness, 0.75, accuracy: 0.001)
        XCTAssertEqual(scores.contextSufficiency, 0.55, accuracy: 0.001)
    }

    // MARK: - 检索快照 (Retrieval Snapshots)

    /// 验证：saveRetrievalSnapshots 空数组是 no-op。
    func testSaveRetrievalSnapshotsEmptyIsNoop() async throws {
        try await store.saveRetrievalSnapshots([])
        // 不应抛出异常
    }

    /// 验证：saveRetrievalSnapshots 后 fetchRetrievalSnapshots 按 rank 排序。
    func testSaveAndFetchRetrievalSnapshots() async throws {
        let eval = RAGEvaluation(
            query: "q1", answer: "a1",
            faithfulness: 0.8, relevance: 0.6, precision: 0.4,
            evaluatorModel: "gpt-4"
        )
        try await store.saveRAGEvaluation(eval)
        let evals = try await store.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(evals.first?.id)

        let snapshots = [
            RetrievalSnapshot(evaluationID: evalID, rank: 2, sourceID: "src2", pageTitle: "t2", snippet: "s2", score: 0.5),
            RetrievalSnapshot(evaluationID: evalID, rank: 1, sourceID: "src1", pageTitle: "t1", snippet: "s1", score: 0.9),
            RetrievalSnapshot(evaluationID: evalID, rank: 3, sourceID: "src3", pageTitle: "t3", snippet: "s3", score: 0.3)
        ]
        try await store.saveRetrievalSnapshots(snapshots)

        let fetched = try await store.fetchRetrievalSnapshots(evaluationID: evalID)
        XCTAssertEqual(fetched.count, 3)
        XCTAssertEqual(fetched[0].rank, 1, "应按 rank 升序")
        XCTAssertEqual(fetched[1].rank, 2)
        XCTAssertEqual(fetched[2].rank, 3)
    }

    // MARK: - 相关性标注 (Relevance Judgments)

    /// 验证：saveRelevanceJudgments 空数组是 no-op。
    func testSaveRelevanceJudgmentsEmptyIsNoop() async throws {
        try await store.saveRelevanceJudgments([])
        // 不应抛出异常
    }

    // MARK: - Hit@K

    /// 验证：calculateHitRate 空数据返回 0。
    func testCalculateHitRateEmpty() async throws {
        let rate = try await store.calculateHitRate(days: 7, k: 3)
        XCTAssertEqual(rate, 0.0)
    }

    /// 验证：calculateHitRate Top-K 中有相关结果时返回 1.0。
    func testCalculateHitRateWithHit() async throws {
        let eval = RAGEvaluation(
            query: "q1", answer: "a1",
            faithfulness: 0.8, relevance: 0.6, precision: 0.4,
            evaluatorModel: "gpt-4"
        )
        try await store.saveRAGEvaluation(eval)
        let evals = try await store.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(evals.first?.id)

        // Top-3 中 rank=1 的 sourceID="src1" 被标注为相关
        try await store.saveRetrievalSnapshots([
            RetrievalSnapshot(evaluationID: evalID, rank: 1, sourceID: "src1", pageTitle: "t1", snippet: "s1", score: 0.9)
        ])
        try await store.saveRelevanceJudgments([
            RelevanceJudgment(queryHash: "hash1", query: "q1", sourceID: "src1", relevanceLevel: 2, evaluationID: evalID)
        ])

        let rate = try await store.calculateHitRate(days: 7, k: 3)
        XCTAssertEqual(rate, 1.0, "Top-K 中有相关结果时 Hit@K 应为 1.0")
    }

    /// 验证：calculateHitRate Top-K 中无相关结果时返回 0。
    func testCalculateHitRateNoHit() async throws {
        let eval = RAGEvaluation(
            query: "q1", answer: "a1",
            faithfulness: 0.8, relevance: 0.6, precision: 0.4,
            evaluatorModel: "gpt-4"
        )
        try await store.saveRAGEvaluation(eval)
        let evals = try await store.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(evals.first?.id)

        // rank=5 超出 K=3，相关结果不在 Top-K
        try await store.saveRetrievalSnapshots([
            RetrievalSnapshot(evaluationID: evalID, rank: 5, sourceID: "src-rel", pageTitle: "t", snippet: "s", score: 0.1)
        ])
        try await store.saveRelevanceJudgments([
            RelevanceJudgment(queryHash: "hash1", query: "q1", sourceID: "src-rel", relevanceLevel: 2, evaluationID: evalID)
        ])

        let rate = try await store.calculateHitRate(days: 7, k: 3)
        XCTAssertEqual(rate, 0.0, "Top-K 中无相关结果时 Hit@K 应为 0")
    }

    // MARK: - MRR

    /// 验证：calculateMRR 空数据返回 0。
    func testCalculateMRREmpty() async throws {
        let mrr = try await store.calculateMRR(days: 7)
        XCTAssertEqual(mrr, 0.0)
    }

    /// 验证：calculateMRR 首个相关结果在 rank=1 时返回 1.0。
    func testCalculateMRRFirstRelevantAtRank1() async throws {
        let eval = RAGEvaluation(
            query: "q1", answer: "a1",
            faithfulness: 0.8, relevance: 0.6, precision: 0.4,
            evaluatorModel: "gpt-4"
        )
        try await store.saveRAGEvaluation(eval)
        let evals = try await store.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(evals.first?.id)

        try await store.saveRetrievalSnapshots([
            RetrievalSnapshot(evaluationID: evalID, rank: 1, sourceID: "src1", pageTitle: "t1", snippet: "s1", score: 0.9),
            RetrievalSnapshot(evaluationID: evalID, rank: 2, sourceID: "src2", pageTitle: "t2", snippet: "s2", score: 0.5)
        ])
        try await store.saveRelevanceJudgments([
            RelevanceJudgment(queryHash: "h1", query: "q1", sourceID: "src1", relevanceLevel: 2, evaluationID: evalID)
        ])

        let mrr = try await store.calculateMRR(days: 7)
        XCTAssertEqual(mrr, 1.0, "首个相关在 rank=1 时 MRR=1.0")
    }

    /// 验证：calculateMRR 首个相关结果在 rank=2 时返回 0.5。
    func testCalculateMRRFirstRelevantAtRank2() async throws {
        let eval = RAGEvaluation(
            query: "q1", answer: "a1",
            faithfulness: 0.8, relevance: 0.6, precision: 0.4,
            evaluatorModel: "gpt-4"
        )
        try await store.saveRAGEvaluation(eval)
        let evals = try await store.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(evals.first?.id)

        try await store.saveRetrievalSnapshots([
            RetrievalSnapshot(evaluationID: evalID, rank: 1, sourceID: "src1", pageTitle: "t1", snippet: "s1", score: 0.9),
            RetrievalSnapshot(evaluationID: evalID, rank: 2, sourceID: "src2", pageTitle: "t2", snippet: "s2", score: 0.5)
        ])
        try await store.saveRelevanceJudgments([
            RelevanceJudgment(queryHash: "h1", query: "q1", sourceID: "src2", relevanceLevel: 2, evaluationID: evalID)
        ])

        let mrr = try await store.calculateMRR(days: 7)
        XCTAssertEqual(mrr, 0.5, accuracy: 0.001, "首个相关在 rank=2 时 MRR=1/2=0.5")
    }

    // MARK: - NDCG@K

    /// 验证：calculateNDCG 空数据返回 0。
    func testCalculateNDCGEmpty() async throws {
        let ndcg = try await store.calculateNDCG(days: 7, k: 3)
        XCTAssertEqual(ndcg, 0.0)
    }

    /// 验证：calculateNDCG 理想排序时返回 1.0。
    func testCalculateNDCGIdealOrder() async throws {
        let eval = RAGEvaluation(
            query: "q1", answer: "a1",
            faithfulness: 0.8, relevance: 0.6, precision: 0.4,
            evaluatorModel: "gpt-4"
        )
        try await store.saveRAGEvaluation(eval)
        let evals = try await store.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(evals.first?.id)

        // rank 顺序与相关性顺序一致（理想排序）
        try await store.saveRetrievalSnapshots([
            RetrievalSnapshot(evaluationID: evalID, rank: 1, sourceID: "src1", pageTitle: "t1", snippet: "s1", score: 0.9),
            RetrievalSnapshot(evaluationID: evalID, rank: 2, sourceID: "src2", pageTitle: "t2", snippet: "s2", score: 0.5),
            RetrievalSnapshot(evaluationID: evalID, rank: 3, sourceID: "src3", pageTitle: "t3", snippet: "s3", score: 0.3)
        ])
        try await store.saveRelevanceJudgments([
            RelevanceJudgment(queryHash: "h1", query: "q1", sourceID: "src1", relevanceLevel: 3, evaluationID: evalID),
            RelevanceJudgment(queryHash: "h2", query: "q1", sourceID: "src2", relevanceLevel: 2, evaluationID: evalID),
            RelevanceJudgment(queryHash: "h3", query: "q1", sourceID: "src3", relevanceLevel: 1, evaluationID: evalID)
        ])

        let ndcg = try await store.calculateNDCG(days: 7, k: 3)
        XCTAssertEqual(ndcg, 1.0, accuracy: 0.001, "理想排序时 NDCG=1.0")
    }

    // MARK: - Recall@K

    /// 验证：calculateRecall 空数据返回 0。
    func testCalculateRecallEmpty() async throws {
        let recall = try await store.calculateRecall(days: 7, k: 3)
        XCTAssertEqual(recall, 0.0)
    }

    /// 验证：calculateRecall Top-K 检索到全部相关时返回 1.0。
    func testCalculateRecallAllRetrieved() async throws {
        let eval = RAGEvaluation(
            query: "q1", answer: "a1",
            faithfulness: 0.8, relevance: 0.6, precision: 0.4,
            evaluatorModel: "gpt-4"
        )
        try await store.saveRAGEvaluation(eval)
        let evals = try await store.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(evals.first?.id)

        try await store.saveRetrievalSnapshots([
            RetrievalSnapshot(evaluationID: evalID, rank: 1, sourceID: "src1", pageTitle: "t1", snippet: "s1", score: 0.9),
            RetrievalSnapshot(evaluationID: evalID, rank: 2, sourceID: "src2", pageTitle: "t2", snippet: "s2", score: 0.5)
        ])
        try await store.saveRelevanceJudgments([
            RelevanceJudgment(queryHash: "h1", query: "q1", sourceID: "src1", relevanceLevel: 2, evaluationID: evalID),
            RelevanceJudgment(queryHash: "h2", query: "q1", sourceID: "src2", relevanceLevel: 2, evaluationID: evalID)
        ])

        let recall = try await store.calculateRecall(days: 7, k: 3)
        XCTAssertEqual(recall, 1.0, accuracy: 0.001, "Top-K 检索到全部相关时 Recall=1.0")
    }

    // MARK: - F1@K

    /// 验证：calculateF1Score 空数据返回 0。
    func testCalculateF1Empty() async throws {
        let f1 = try await store.calculateF1Score(days: 7, k: 3)
        XCTAssertEqual(f1, 0.0)
    }

    // MARK: - MAP

    /// 验证：calculateMAP 空数据返回 0。
    func testCalculateMAPEmpty() async throws {
        let map = try await store.calculateMAP(days: 7)
        XCTAssertEqual(map, 0.0)
    }

    // MARK: - 检索延迟百分位

    /// 验证：calculateRetrievalLatency 空数据返回全 0。
    func testCalculateRetrievalLatencyEmpty() async throws {
        let latency = try await store.calculateRetrievalLatency(days: 7)
        XCTAssertEqual(latency.p50, 0)
        XCTAssertEqual(latency.p95, 0)
        XCTAssertEqual(latency.p99, 0)
        XCTAssertEqual(latency.sampleCount, 0)
    }

    /// 验证：calculateRetrievalLatency 正确计算百分位。
    func testCalculateRetrievalLatency() async throws {
        // 插入 100 条延迟记录：1ms..100ms
        for i in 1...100 {
            try await store.logCall(model: "gpt-4", promptTokens: 10, completionTokens: 5, latencyMS: i, status: "success")
        }

        let latency = try await store.calculateRetrievalLatency(days: 7)
        XCTAssertEqual(latency.sampleCount, 100)
        XCTAssertEqual(latency.p50, 50, "p50 应为 50ms")
        XCTAssertEqual(latency.p95, 95, "p95 应为 95ms")
        XCTAssertEqual(latency.p99, 99, "p99 应为 99ms")
    }

    // MARK: - Token 效率

    /// 验证：calculateTokenEfficiency 空数据返回全 0。
    func testCalculateTokenEfficiencyEmpty() async throws {
        let eff = try await store.calculateTokenEfficiency(days: 7)
        XCTAssertEqual(eff.totalTokens, 0)
        XCTAssertEqual(eff.queryCount, 0)
        XCTAssertEqual(eff.avgTokensPerQuery, 0.0)
        XCTAssertEqual(eff.estimatedCostUSD, 0.0)
    }

    /// 验证：calculateTokenEfficiency 正确计算。
    func testCalculateTokenEfficiency() async throws {
        try await store.logTokenUsage(model: "gpt-4", promptTokens: 1000, completionTokens: 500)
        try await store.logTokenUsage(model: "gpt-4", promptTokens: 2000, completionTokens: 1000)

        let eff = try await store.calculateTokenEfficiency(days: 7)
        XCTAssertEqual(eff.totalTokens, 4500)
        XCTAssertEqual(eff.queryCount, 2)
        XCTAssertEqual(eff.avgTokensPerQuery, 2250.0, accuracy: 0.001)
        XCTAssertGreaterThan(eff.estimatedCostUSD, 0.0, "应有非零成本")
    }

    // MARK: - updateUserRating

    /// 验证：updateUserRating 对不存在的 ID 静默返回。
    func testUpdateUserRatingNonExistentIsSilent() async throws {
        try await store.updateUserRating(evaluationID: 99999, rating: 5)
        // 不应抛出异常
    }

    /// 验证：updateUserRating 正确更新评分。
    func testUpdateUserRatingUpdatesRating() async throws {
        let eval = RAGEvaluation(
            query: "q1", answer: "a1",
            faithfulness: 0.8, relevance: 0.6, precision: 0.4,
            evaluatorModel: "gpt-4"
        )
        try await store.saveRAGEvaluation(eval)
        let evals = try await store.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(evals.first?.id)

        try await store.updateUserRating(evaluationID: evalID, rating: 4)

        let updated = try await store.fetchRAGEvaluations(limit: 1).first
        XCTAssertEqual(updated?.userRating, 4, "用户评分应更新为 4")
    }
}

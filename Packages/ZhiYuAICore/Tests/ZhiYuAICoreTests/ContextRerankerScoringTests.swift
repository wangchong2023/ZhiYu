//
//  ContextRerankerScoringTests.swift
//  ZhiYuAICoreTests
//
//  系统层级：[ZhiYuAICoreTests]
//  核心职责：验证 ContextReranker 的评分算法语义。
//           finalScore = initialScore * 0.7 + crossScore * 0.3，minScore 阈值必须正确剪枝。
//

import XCTest
@testable import ZhiYuAICore

final class ContextRerankerScoringTests: XCTestCase {

    /// 高 initialScore + 高 crossScore 必须排在前面
    func testHighScoreRankedFirst() {
        let reranker = ContextReranker()
        let query = "kubernetes deployment"

        let candidates: [(chunk: ContextRerankChunk, initialScore: Float)] = [
            (ContextRerankChunk(id: "1", content: "kubernetes deployment guide", index: 0), 0.8),
            (ContextRerankChunk(id: "2", content: "irrelevant content", index: 1), 0.5)
        ]

        let result = reranker.rerank(query: query, candidates: candidates, topK: 2, minScore: 0.0)
        XCTAssertEqual(result.first?.chunk.id, "1", "高相关 chunk 必须排第一")
    }

    /// minScore 阈值必须剪枝低分候选
    func testMinScorePruning() {
        let reranker = ContextReranker()
        let query = "test"

        let candidates: [(chunk: ContextRerankChunk, initialScore: Float)] = [
            (ContextRerankChunk(id: "1", content: "test content", index: 0), 0.9),
            (ContextRerankChunk(id: "2", content: "no match", index: 1), 0.1)
        ]

        let result = reranker.rerank(query: query, candidates: candidates, topK: 5, minScore: 0.5)
        XCTAssertEqual(result.count, 1, "minScore=0.5 必须剪枝得分 0.1 的候选")
        XCTAssertEqual(result.first?.chunk.id, "1")
    }

    /// topK 必须限制返回数量
    func testTopKLimit() {
        let reranker = ContextReranker()
        let query = "common"

        let candidates: [(chunk: ContextRerankChunk, initialScore: Float)] = (0..<10).map { i in
            (ContextRerankChunk(id: "\(i)", content: "common word \(i)", index: i), 0.8)
        }

        let result = reranker.rerank(query: query, candidates: candidates, topK: 3, minScore: 0.0)
        XCTAssertEqual(result.count, 3, "topK=3 必须只返回 3 个结果")
    }

    /// 空 query 时 crossScore 必须为 0（不崩溃）
    func testEmptyQueryCrossScoreZero() {
        let reranker = ContextReranker()
        let candidates: [(chunk: ContextRerankChunk, initialScore: Float)] = [
            (ContextRerankChunk(id: "1", content: "content", index: 0), 0.6)
        ]

        let result = reranker.rerank(query: "", candidates: candidates, topK: 5, minScore: 0.0)
        XCTAssertEqual(result.count, 1)
        // finalScore = 0.6 * 0.7 + 0 * 0.3 = 0.42
        XCTAssertEqual(result[0].score, 0.42, accuracy: 0.01)
    }

    /// 空候选列表必须返回空结果
    func testEmptyCandidatesReturnsEmpty() {
        let reranker = ContextReranker()
        let result = reranker.rerank(query: "test", candidates: [], topK: 5, minScore: 0.0)
        XCTAssertTrue(result.isEmpty)
    }

    /// 所有候选低于 minScore 时返回空
    func testAllBelowMinScoreReturnsEmpty() {
        let reranker = ContextReranker()
        let candidates: [(chunk: ContextRerankChunk, initialScore: Float)] = [
            (ContextRerankChunk(id: "1", content: "no match", index: 0), 0.1),
            (ContextRerankChunk(id: "2", content: "also no match", index: 1), 0.2)
        ]

        let result = reranker.rerank(query: "unique query", candidates: candidates, topK: 5, minScore: 0.9)
        XCTAssertTrue(result.isEmpty, "所有候选低于 minScore 时必须返回空")
    }

    /// 结果必须按 score 降序排列
    func testResultsSortedByScoreDescending() {
        let reranker = ContextReranker()
        let query = "alpha beta"

        let candidates: [(chunk: ContextRerankChunk, initialScore: Float)] = [
            (ContextRerankChunk(id: "low", content: "alpha", index: 0), 0.3),
            (ContextRerankChunk(id: "high", content: "alpha beta gamma", index: 1), 0.9),
            (ContextRerankChunk(id: "mid", content: "alpha beta", index: 2), 0.6)
        ]

        let result = reranker.rerank(query: query, candidates: candidates, topK: 3, minScore: 0.0)
        XCTAssertEqual(result.count, 3)
        for i in 1..<result.count {
            XCTAssertGreaterThanOrEqual(result[i-1].score, result[i].score,
                                        "结果必须按 score 降序排列")
        }
    }

    /// crossScore 计算：query tokens 与 chunk tokens 的 Jaccard 相似度
    func testCrossScoreCalculation() {
        let reranker = ContextReranker()
        let query = "kubernetes pods"

        // chunk 包含 query 的 1/2 tokens → crossScore = 0.5
        let candidates: [(chunk: ContextRerankChunk, initialScore: Float)] = [
            (ContextRerankChunk(id: "1", content: "kubernetes services", index: 0), 0.0)
        ]

        let result = reranker.rerank(query: query, candidates: candidates, topK: 5, minScore: 0.0)
        XCTAssertEqual(result.count, 1)
        // finalScore = 0 * 0.7 + 0.5 * 0.3 = 0.15
        XCTAssertEqual(result[0].score, 0.15, accuracy: 0.01)
    }
}

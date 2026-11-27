//
//  ContextRerankerEdgeCaseTests.swift
//  ZhiYuAICoreTests
//
//  系统层级：[ZhiYuAICoreTests]
//  核心职责：验证 ContextReranker 的边界场景与数据结构契约。
//

import XCTest
@testable import ZhiYuAICore

final class ContextRerankerEdgeCaseTests: XCTestCase {

    /// ContextRerankChunk 默认 id 必须唯一
    func testChunkDefaultIdUnique() {
        let chunk1 = ContextRerankChunk(content: "a", index: 0)
        let chunk2 = ContextRerankChunk(content: "b", index: 1)
        XCTAssertNotEqual(chunk1.id, chunk2.id)
    }

    /// ContextRerankChunk 必须是 Sendable
    func testChunkIsSendable() async {
        let chunk = ContextRerankChunk(id: "1", content: "test", index: 0)
        await Task {
            XCTAssertEqual(chunk.content, "test")
        }.value
    }

    /// RerankedResult 必须正确初始化
    func testRerankedResultInit() {
        let chunk = ContextRerankChunk(id: "1", content: "test", index: 0)
        let result = RerankedResult(chunk: chunk, score: 0.85)
        XCTAssertEqual(result.chunk.id, "1")
        XCTAssertEqual(result.score, 0.85)
    }

    /// ContextReranker 必须是 Sendable（可跨 actor 传递）
    func testRerankerIsSendable() async {
        let reranker = ContextReranker()
        await Task {
            let result = reranker.rerank(query: "test", candidates: [], topK: 5, minScore: 0.0)
            XCTAssertTrue(result.isEmpty)
        }.value
    }

    /// topK=0 必须返回空结果
    func testTopKZeroReturnsEmpty() {
        let reranker = ContextReranker()
        let candidates: [(chunk: ContextRerankChunk, initialScore: Float)] = [
            (ContextRerankChunk(id: "1", content: "test", index: 0), 0.9)
        ]
        let result = reranker.rerank(query: "test", candidates: candidates, topK: 0, minScore: 0.0)
        XCTAssertTrue(result.isEmpty, "topK=0 必须返回空")
    }

    /// minScore 为负数时所有候选都应保留（无剪枝）
    func testNegativeMinScoreNoPruning() {
        let reranker = ContextReranker()
        let candidates: [(chunk: ContextRerankChunk, initialScore: Float)] = [
            (ContextRerankChunk(id: "1", content: "test", index: 0), 0.0)
        ]
        let result = reranker.rerank(query: "test", candidates: candidates, topK: 5, minScore: -1.0)
        XCTAssertEqual(result.count, 1)
    }

    /// 重复 content 的 chunk 必须独立处理
    func testDuplicateContentChunksIndependent() {
        let reranker = ContextReranker()
        let candidates: [(chunk: ContextRerankChunk, initialScore: Float)] = [
            (ContextRerankChunk(id: "1", content: "same", index: 0), 0.5),
            (ContextRerankChunk(id: "2", content: "same", index: 1), 0.5)
        ]
        let result = reranker.rerank(query: "same", candidates: candidates, topK: 5, minScore: 0.0)
        XCTAssertEqual(result.count, 2, "重复 content 的 chunk 必须独立保留")
    }

    /// 缺陷 #170 回归：负数 topK 不得触发 prefix 致命崩溃，NaN/Inf 初始分数与非有限 minScore 必须安全过滤
    func testNegativeTopKAndNonFiniteScoresHandledSafely() {
        let reranker = ContextReranker()
        let candidates: [(chunk: ContextRerankChunk, initialScore: Float)] = [
            (ContextRerankChunk(id: "nan", content: "swift concurrency", index: 0), .nan),
            (ContextRerankChunk(id: "inf", content: "swift concurrency", index: 1), .infinity),
            (ContextRerankChunk(id: "negInf", content: "swift concurrency", index: 2), -.infinity),
            (ContextRerankChunk(id: "valid", content: "swift concurrency", index: 3), 0.8)
        ]

        // 1. 负数 topK 返回空数组而非崩溃
        XCTAssertTrue(reranker.rerank(query: "swift", candidates: candidates, topK: -5, minScore: 0.0).isEmpty)

        // 2. 非有限 minScore 返回空数组
        XCTAssertTrue(reranker.rerank(query: "swift", candidates: candidates, topK: 5, minScore: .nan).isEmpty)
        XCTAssertTrue(reranker.rerank(query: "swift", candidates: candidates, topK: 5, minScore: .infinity).isEmpty)

        // 3. 过滤所有 NaN/±Inf 候选，仅保留有限分数的有效候选
        let filtered = reranker.rerank(query: "swift", candidates: candidates, topK: 5, minScore: 0.0)
        XCTAssertEqual(filtered.map(\.chunk.id), ["valid"], "仅有限分数的候选应保留，NaN/Inf 不得污染排序")
    }
}

//
//  StorageAndVectorResilienceTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：验证 TransactionGatekeeper 事务门禁排空容灾、ContextReranker 极端边界（负数 topK、NaN 分数）与 VectorIndexer 索引调度韧性。
//

#if !os(watchOS)
import XCTest
import UFPCore
import UFPStorage
@testable import ZhiYu

final class StorageAndVectorResilienceTests: XCTestCase {

    // MARK: - 1. ContextReranker 极端边界与容灾测试

    func testContextReranker_NegativeTopK_ReturnsEmptyWithoutCrashing() {
        let reranker = ContextReranker()
        let chunk = PageChunk(
            id: "chunk-1",
            pageID: UUID(),
            chunkType: .paragraph,
            content: "端侧大模型 RAG 架构设计",
            index: 0
        )
        let candidates = [(chunk: chunk, score: Float(0.85))]

        // 验证传入负数 topK 不会因负向 Array Slice 产生致命闪退
        let resultNegativeOne = reranker.rerank(query: "架构", candidates: candidates, topK: -1)
        XCTAssertTrue(resultNegativeOne.isEmpty, "负数 topK 必须返回空切片列表而不能闪退崩溃")

        let resultNegativeTen = reranker.rerank(query: "架构", candidates: candidates, topK: -10)
        XCTAssertTrue(resultNegativeTen.isEmpty)
    }

    func testContextReranker_ZeroTopK_ReturnsEmpty() {
        let reranker = ContextReranker()
        let chunk = PageChunk(
            id: "chunk-1",
            pageID: UUID(),
            chunkType: .paragraph,
            content: "端侧大模型 RAG 架构设计",
            index: 0
        )
        let candidates = [(chunk: chunk, score: Float(0.85))]

        let result = reranker.rerank(query: "架构", candidates: candidates, topK: 0)
        XCTAssertTrue(result.isEmpty, "topK 为 0 应返回空切片列表")
    }

    func testContextReranker_CandidateWithNaNAndInfinity_PrunesSafely() {
        let reranker = ContextReranker()
        let validChunk = PageChunk(
            id: "chunk-valid",
            pageID: UUID(),
            chunkType: .paragraph,
            content: "有效切片内容",
            index: 0
        )
        let nanChunk = PageChunk(
            id: "chunk-nan",
            pageID: UUID(),
            chunkType: .paragraph,
            content: "NaN 分值异常切片",
            index: 1
        )
        let infChunk = PageChunk(
            id: "chunk-inf",
            pageID: UUID(),
            chunkType: .paragraph,
            content: "无穷大分值异常切片",
            index: 2
        )

        let candidates = [
            (chunk: validChunk, score: Float(0.7)),
            (chunk: nanChunk, score: Float.nan),
            (chunk: infChunk, score: Float.infinity)
        ]

        let results = reranker.rerank(query: "内容", candidates: candidates, topK: 5, minScore: 0.35)
        XCTAssertEqual(results.count, 1, "非法 NaN 与 Infinity 分值候选切片必须被彻底剪枝过滤")
        XCTAssertEqual(results.first?.chunk.index, 0)
    }

    func testContextReranker_CaseInsensitiveQueryTokens_CalculatesBonusCorrectly() {
        let reranker = ContextReranker()
        let chunk = PageChunk(
            id: "chunk-swift",
            pageID: UUID(),
            chunkType: .paragraph,
            content: "Swift 6 Strict Concurrency Architecture",
            index: 0
        )
        let candidates = [(chunk: chunk, score: Float(0.5))]

        // 大小写混合查询
        let resultLower = reranker.rerank(query: "swift architecture", candidates: candidates)
        let resultUpper = reranker.rerank(query: "SWIFT ARCHITECTURE", candidates: candidates)

        XCTAssertEqual(resultLower.count, 1)
        XCTAssertEqual(resultUpper.count, 1)
        XCTAssertEqual(resultLower[0].score, resultUpper[0].score, "查询关键词大小写不应影响加成计算")
        XCTAssertGreaterThan(resultLower[0].score, 0.5, "精准命中关键词应获得加成")
    }

    func testContextReranker_EmptyQuery_CalculatesNoBonus() {
        let reranker = ContextReranker()
        let chunk = PageChunk(
            id: "chunk-plain",
            pageID: UUID(),
            chunkType: .paragraph,
            content: "普通切片文本",
            index: 0
        )
        let candidates = [(chunk: chunk, score: Float(0.6))]

        let result = reranker.rerank(query: "   \t  ", candidates: candidates)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].score, 0.6, accuracy: 0.001, "空白查询词不应触发任何关键词加成")
    }

    // MARK: - 2. TransactionGatekeeper 事务排空与容灾测试

    func testTransactionGatekeeper_AcquireAndRelease_UpdatesActiveCount() async throws {
        let gatekeeper = TransactionGatekeeper()
        await gatekeeper.reset()

        let initialCount = await gatekeeper.activeCount
        XCTAssertEqual(initialCount, 0)

        try await gatekeeper.acquire()
        let countAfterAcquire = await gatekeeper.activeCount
        XCTAssertEqual(countAfterAcquire, 1)

        await gatekeeper.release()
        let countAfterRelease = await gatekeeper.activeCount
        XCTAssertEqual(countAfterRelease, 0)
    }

    func testTransactionGatekeeper_ReleaseWhenZero_DoesNotUnderflow() async {
        let gatekeeper = TransactionGatekeeper()
        await gatekeeper.reset()

        // 连续多次 release 不应发生下溢或负数
        await gatekeeper.release()
        await gatekeeper.release()

        let count = await gatekeeper.activeCount
        XCTAssertEqual(count, 0, "计数器为 0 时 release 绝不能下溢为负数")
    }

    func testTransactionGatekeeper_AcquireDuringDraining_ThrowsDrainingError() async {
        let gatekeeper = TransactionGatekeeper()
        await gatekeeper.reset()
        await gatekeeper.setDrainingForTesting(true)

        do {
            try await gatekeeper.acquire()
            XCTFail("排空期间 acquire 必须抛出 DatabaseError.draining 错误")
        } catch let error as ZhiYu.DatabaseError {
            XCTAssertEqual(error, ZhiYu.DatabaseError.draining)
        } catch {
            XCTFail("捕获到非预期的错误类型: \(error)")
        }

        await gatekeeper.reset()
    }

    func testTransactionGatekeeper_DrainWhenZero_ReturnsTrueImmediately() async {
        let gatekeeper = TransactionGatekeeper()
        await gatekeeper.reset()

        let success = await gatekeeper.drain(maxWaitTime: .milliseconds(50))
        XCTAssertTrue(success, "无活跃事务时 drain 必须立即返回 true")

        let isDraining = await gatekeeper.draining
        XCTAssertFalse(isDraining, "drain 结束后 draining 状态必须恢复为 false")
    }

    func testTransactionGatekeeper_DrainWaitsForRelease_Succeeds() async throws {
        let gatekeeper = TransactionGatekeeper()
        await gatekeeper.reset()

        try await gatekeeper.acquire()

        // 异步在 50ms 后释放事务许可
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            await gatekeeper.release()
        }

        let success = await gatekeeper.drain(maxWaitTime: .milliseconds(500))
        XCTAssertTrue(success, "在超时前释放事务许可应使 drain 成功返回 true")

        let finalCount = await gatekeeper.activeCount
        XCTAssertEqual(finalCount, 0)
    }

    func testTransactionGatekeeper_DrainTimeout_ReturnsFalseAndClearsDraining() async throws {
        let gatekeeper = TransactionGatekeeper()
        await gatekeeper.reset()

        try await gatekeeper.acquire()

        // 事务一直未释放，等待 30ms 超时
        let success = await gatekeeper.drain(maxWaitTime: .milliseconds(30))
        XCTAssertFalse(success, "事务未排空超时必须返回 false")

        let isDraining = await gatekeeper.draining
        XCTAssertFalse(isDraining, "超时后 draining 标志位必须重置为 false")

        await gatekeeper.reset()
    }

    func testTransactionGatekeeper_Reset_ClearsAllState() async throws {
        let gatekeeper = TransactionGatekeeper()
        try await gatekeeper.acquire()
        await gatekeeper.setDrainingForTesting(true)

        await gatekeeper.reset()

        let count = await gatekeeper.activeCount
        let draining = await gatekeeper.draining
        XCTAssertEqual(count, 0)
        XCTAssertFalse(draining)
    }

    // MARK: - 3. VectorIndexer 索引空状态拦截测试

    func testVectorIndexer_EmptyChunks_ReturnsImmediatelyWithoutIndexing() async {
        let mockProvider = MockEmbeddingProvider()
        let indexer = VectorIndexer(embeddingProvider: mockProvider)

        await indexer.index(pageID: UUID(), chunks: [])

        XCTAssertFalse(mockProvider.didCallIndexChunks, "分块列表为空时 VectorIndexer 应直接快速短路返回")
    }
}

// MARK: - Mock Embedding Provider

private final class MockEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    private let inner = NoOpEmbeddingProvider()
    var didCallIndexChunks = false

    func getAllEmbeddings() async -> [UUID: [Float]] { await inner.getAllEmbeddings() }
    func syncEmbeddings(pages: [KnowledgePage]) async { await inner.syncEmbeddings(pages: pages) }
    func updateEmbedding(for page: KnowledgePage) async { await inner.updateEmbedding(for: page) }
    func indexChunks(pageID: UUID, chunks: [PageChunk]) async {
        didCallIndexChunks = true
    }
    func vectorizeChunks(chunks: [String]) async -> [[Float]] { await inner.vectorizeChunks(chunks: chunks) }
    func search(query: String, topK: Int) async -> [(id: UUID, score: Float)] { await inner.search(query: query, topK: topK) }
    func multiQuerySearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { await inner.multiQuerySearch(query: query, topK: topK) }
    func hydeSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { await inner.hydeSearch(query: query, topK: topK) }
    func selfReflectionSearch(query: String, candidates: [(chunk: PageChunk, score: Float)]) async -> [(chunk: PageChunk, score: Float)] { await inner.selfReflectionSearch(query: query, candidates: candidates) }
    func advancedSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { await inner.advancedSearch(query: query, topK: topK) }
    func loadInitialCache() async { await inner.loadInitialCache() }
    func clearCacheAndReload() async { await inner.clearCacheAndReload() }
}
#endif

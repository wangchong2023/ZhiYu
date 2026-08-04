//
//  QueryRerankerDegradationTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 QueryReranker 在未配置或子服务不可用时的降级返回语义。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class QueryRerankerDegradationTests: XCTestCase {

    private var config: LLMConfigManager!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        config = LLMConfigManager()
        ServiceContainer.shared.register(config, for: LLMConfigManager.self)
    }

    override func tearDown() async throws {
        config = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 未启用时的降级

    func testRewriteQueryReturnsOriginalWhenDisabled() async {
        config.isEnabled = false
        config.apiKey = "test-key"
        let reranker = QueryReranker()
        let result = await reranker.rewriteQuery("原始查询")
        XCTAssertEqual(result, "原始查询", "isEnabled=false 时应降级返回原始查询")
    }

    func testExpandQueryReturnsSingleWhenDisabled() async {
        config.isEnabled = false
        config.apiKey = "test-key"
        let reranker = QueryReranker()
        let result = await reranker.expandQuery("查询")
        XCTAssertEqual(result, ["查询"], "isEnabled=false 时应降级返回仅含原始查询的数组")
    }

    func testRerankReturnsOriginalWhenDisabled() async throws {
        config.isEnabled = false
        config.apiKey = "test-key"
        let reranker = QueryReranker()
        let candidates: [any KnowledgePageRepresentable] = [
            KnowledgePage(title: "A", pageType: .entity, content: "A"),
            KnowledgePage(title: "B", pageType: .concept, content: "B")
        ]
        let result = try await reranker.rerank(query: "Q", candidates: candidates)
        XCTAssertEqual(result.count, 2, "isEnabled=false 时应降级返回原始候选集")
    }

    func testRerankChunksReturnsOriginalWhenDisabled() async {
        config.isEnabled = false
        config.apiKey = "test-key"
        let reranker = QueryReranker()
        let chunks = [
            PageChunk(id: "test_0", pageID: UUID(), chunkType: "text", content: "c1", anchorPath: nil, index: 0),
            PageChunk(id: "test_1", pageID: UUID(), chunkType: "text", content: "c2", anchorPath: nil, index: 1)
        ]
        let result = await reranker.rerankChunks(query: "Q", chunks: chunks)
        XCTAssertEqual(result.count, 2, "isEnabled=false 时应降级返回原始 chunks")
    }

    func testGenerateHypotheticalReturnsQueryWhenDisabled() async {
        config.isEnabled = false
        config.apiKey = "test-key"
        let reranker = QueryReranker()
        let result = await reranker.generateHypotheticalDocument(query: "查询")
        XCTAssertEqual(result, "查询", "isEnabled=false 时应降级返回原始查询")
    }

    // MARK: - API Key 为空时的降级

    func testRewriteQueryReturnsOriginalWhenApiKeyEmpty() async {
        config.isEnabled = true
        config.apiKey = ""
        let reranker = QueryReranker()
        let result = await reranker.rewriteQuery("原始查询")
        XCTAssertEqual(result, "原始查询", "apiKey 为空时应降级返回原始查询")
    }

    func testExpandQueryReturnsSingleWhenApiKeyEmpty() async {
        config.isEnabled = true
        config.apiKey = ""
        let reranker = QueryReranker()
        let result = await reranker.expandQuery("查询")
        XCTAssertEqual(result, ["查询"], "apiKey 为空时应降级返回仅含原始查询的数组")
    }

    func testRerankReturnsOriginalWhenApiKeyEmpty() async throws {
        config.isEnabled = true
        config.apiKey = ""
        let reranker = QueryReranker()
        let candidates: [any KnowledgePageRepresentable] = [
            KnowledgePage(title: "A", pageType: .entity, content: "A")
        ]
        let result = try await reranker.rerank(query: "Q", candidates: candidates)
        XCTAssertEqual(result.count, 1, "apiKey 为空时应降级返回原始候选集")
    }

    // MARK: - 空查询边界

    func testRewriteQueryWithEmptyString() async {
        config.isEnabled = false
        config.apiKey = "key"
        let reranker = QueryReranker()
        let result = await reranker.rewriteQuery("")
        XCTAssertEqual(result, "", "空查询降级应返回空字符串")
    }

    func testExpandQueryWithEmptyString() async {
        config.isEnabled = false
        config.apiKey = "key"
        let reranker = QueryReranker()
        let result = await reranker.expandQuery("")
        XCTAssertEqual(result, [""], "空查询降级应返回含空字符串的数组")
    }
}

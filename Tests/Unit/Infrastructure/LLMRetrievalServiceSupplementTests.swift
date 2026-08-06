//
//  LLMRetrievalServiceSupplementTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：补充 LLMRetrievalService 的 expandQuery/rerankChunks/generateHypotheticalDocument 及错误降级路径测试。
//

import XCTest
@testable import ZhiYu

final class LLMRetrievalServiceSupplementTests: XCTestCase {

    private var mockClient: MockLLMClient!
    private var contextBuilder: LLMContextBuilder!

    override func setUp() {
        super.setUp()
        mockClient = MockLLMClient()
        contextBuilder = LLMContextBuilder()
    }

    override func tearDown() {
        mockClient = nil
        contextBuilder = nil
        super.tearDown()
    }

    // MARK: - expandQuery

    func testExpandQuery_validJSONArray_returnsVariations() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": "[\"expanded1\", \"expanded2\", \"expanded3\"]"]
            ]]
        ]

        let result = await service.expandQuery("original query")

        XCTAssertEqual(result, ["expanded1", "expanded2", "expanded3"])
    }

    func testExpandQuery_emptyArrayFallsBackToOriginalQuery() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": "[]"]
            ]]
        ]

        let result = await service.expandQuery("original query")

        XCTAssertEqual(result, ["original query"], "空数组应降级返回原始查询")
    }

    func testExpandQuery_invalidJSONFallsBackToOriginalQuery() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": "not a json array"]
            ]]
        ]

        let result = await service.expandQuery("original query")

        XCTAssertEqual(result, ["original query"], "无效 JSON 应降级返回原始查询")
    }

    func testExpandQuery_clientThrowsFallsBackToOriginalQuery() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        mockClient.mockError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)

        let result = await service.expandQuery("original query")

        XCTAssertEqual(result, ["original query"], "客户端抛错应降级返回原始查询")
    }

    // MARK: - rewriteQuery 错误降级

    func testRewriteQuery_clientThrowsFallsBackToOriginalQuery() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        mockClient.mockError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)

        let result = await service.rewriteQuery("original query")

        XCTAssertEqual(result, "original query", "客户端抛错应降级返回原始查询")
    }

    /// 空 content 应降级返回原始查询（修复后空字符串被视为失败）。
    func testRewriteQuery_emptyContentFallsBackToOriginalQuery() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": ""]
            ]]
        ]

        let result = await service.rewriteQuery("original query")

        XCTAssertEqual(result, "original query", "空 content 应降级返回原始查询")
    }

    // MARK: - rerank 边界

    func testRerank_emptyCandidates_returnsEmpty() async throws {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)

        let result = try await service.rerank(query: "test", candidates: [])

        XCTAssertTrue(result.isEmpty, "空候选列表应直接返回空")
    }

    func testRerank_clientThrows_propagatesError() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        mockClient.mockError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let page = KnowledgePage(title: "P1", pageType: .concept, content: "C1")

        do {
            _ = try await service.rerank(query: "test", candidates: [page])
            XCTFail("应抛出错误")
        } catch {
            XCTAssertTrue(true, "rerank 应向上抛出错误而非降级")
        }
    }

    func testRerank_unmatchedIDs_keepsOriginalOrder() async throws {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        let page1 = KnowledgePage(title: "P1", pageType: .concept, content: "C1")
        let page2 = KnowledgePage(title: "P2", pageType: .concept, content: "C2")

        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": "[\"unknown-id-1\", \"unknown-id-2\"]"]
            ]]
        ]

        let result = try await service.rerank(query: "test", candidates: [page1, page2])

        XCTAssertEqual(result.count, 2, "未匹配 ID 应保持原顺序")
        XCTAssertEqual(result[0].id, page1.id)
        XCTAssertEqual(result[1].id, page2.id)
    }

    // MARK: - rerankChunks

    func testRerankChunks_emptyChunks_returnsEmpty() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)

        let result = await service.rerankChunks(query: "test", chunks: [])

        XCTAssertTrue(result.isEmpty, "空 chunks 应直接返回空")
    }

    /// 数字数组索引 `[1,0,2]`（修复后 `parseJSONArray` 兼容数字数组）。
    func testRerankChunks_numericArrayIndices_reordersCorrectly() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        let pageID = UUID()
        let chunk1 = PageChunk(id: "c1", pageID: pageID, content: "content1", index: 0)
        let chunk2 = PageChunk(id: "c2", pageID: pageID, content: "content2", index: 1)
        let chunk3 = PageChunk(id: "c3", pageID: pageID, content: "content3", index: 2)

        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": "[1, 0, 2]"]
            ]]
        ]

        let result = await service.rerankChunks(query: "test", chunks: [chunk1, chunk2, chunk3])

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].id, "c2", "索引 1 应排第一")
        XCTAssertEqual(result[1].id, "c1", "索引 0 应排第二")
        XCTAssertEqual(result[2].id, "c3", "索引 2 应排第三")
    }

    /// 字符串数组索引 `["1","0","2"]` 也可以正确解析。
    func testRerankChunks_stringArrayIndices_reordersCorrectly() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        let pageID = UUID()
        let chunk1 = PageChunk(id: "c1", pageID: pageID, content: "content1", index: 0)
        let chunk2 = PageChunk(id: "c2", pageID: pageID, content: "content2", index: 1)
        let chunk3 = PageChunk(id: "c3", pageID: pageID, content: "content3", index: 2)

        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": "[\"1\", \"0\", \"2\"]"]
            ]]
        ]

        let result = await service.rerankChunks(query: "test", chunks: [chunk1, chunk2, chunk3])

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].id, "c2", "索引 1 应排第一")
        XCTAssertEqual(result[1].id, "c1", "索引 0 应排第二")
        XCTAssertEqual(result[2].id, "c3", "索引 2 应排第三")
    }

    /// 部分数字数组索引 `[2]`（修复后兼容），选中 c3，其余按原顺序追加。
    func testRerankChunks_partialNumericIndices_appendsUnselected() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        let pageID = UUID()
        let chunk1 = PageChunk(id: "c1", pageID: pageID, content: "content1", index: 0)
        let chunk2 = PageChunk(id: "c2", pageID: pageID, content: "content2", index: 1)
        let chunk3 = PageChunk(id: "c3", pageID: pageID, content: "content3", index: 2)

        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": "[2]"]
            ]]
        ]

        let result = await service.rerankChunks(query: "test", chunks: [chunk1, chunk2, chunk3])

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].id, "c3", "索引 2 应排第一")
        let remaining = Set(result.dropFirst().map { $0.id })
        XCTAssertEqual(remaining, ["c1", "c2"], "未选中块应追加在末尾")
    }

    /// 部分字符串数组索引 `["2"]`，选中 c3，其余按原顺序追加。
    func testRerankChunks_partialStringIndices_appendsUnselected() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        let pageID = UUID()
        let chunk1 = PageChunk(id: "c1", pageID: pageID, content: "content1", index: 0)
        let chunk2 = PageChunk(id: "c2", pageID: pageID, content: "content2", index: 1)
        let chunk3 = PageChunk(id: "c3", pageID: pageID, content: "content3", index: 2)

        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": "[\"2\"]"]
            ]]
        ]

        let result = await service.rerankChunks(query: "test", chunks: [chunk1, chunk2, chunk3])

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].id, "c3", "索引 2 应排第一")
        let remaining = Set(result.dropFirst().map { $0.id })
        XCTAssertEqual(remaining, ["c1", "c2"], "未选中块应追加在末尾")
    }

    func testRerankChunks_outOfBoundsIndices_areSkipped() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        let pageID = UUID()
        let chunk1 = PageChunk(id: "c1", pageID: pageID, content: "content1", index: 0)

        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": "[0, 99, 100]"]
            ]]
        ]

        let result = await service.rerankChunks(query: "test", chunks: [chunk1])

        XCTAssertEqual(result.count, 1, "越界索引应被跳过")
        XCTAssertEqual(result[0].id, "c1")
    }

    func testRerankChunks_clientThrows_returnsOriginalChunks() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        mockClient.mockError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let pageID = UUID()
        let chunk1 = PageChunk(id: "c1", pageID: pageID, content: "content1", index: 0)
        let chunk2 = PageChunk(id: "c2", pageID: pageID, content: "content2", index: 1)

        let result = await service.rerankChunks(query: "test", chunks: [chunk1, chunk2])

        XCTAssertEqual(result.count, 2, "客户端抛错应返回原始 chunks")
        XCTAssertEqual(result[0].id, "c1")
        XCTAssertEqual(result[1].id, "c2")
    }

    // MARK: - generateHypotheticalDocument

    func testGenerateHypotheticalDocument_validContent_returnsContent() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": "Hypothetical answer text"]
            ]]
        ]

        let result = await service.generateHypotheticalDocument(query: "what is X?")

        XCTAssertEqual(result, "Hypothetical answer text")
    }

    func testGenerateHypotheticalDocument_clientThrowsFallsBackToQuery() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        mockClient.mockError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)

        let result = await service.generateHypotheticalDocument(query: "what is X?")

        XCTAssertEqual(result, "what is X?", "客户端抛错应降级返回原始查询")
    }

    /// 空 content 应降级返回原始查询（修复后空字符串被视为失败）。
    func testGenerateHypotheticalDocument_emptyContentFallsBackToQuery() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": ""]
            ]]
        ]

        let result = await service.generateHypotheticalDocument(query: "what is X?")

        XCTAssertEqual(result, "what is X?", "空 content 应降级返回原始查询")
    }

    func testGenerateHypotheticalDocument_reasoningContentFallback() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        mockClient.mockResponse = [
            "choices": [[
                "message": ["reasoning_content": "Reasoning-based answer"]
            ]]
        ]

        let result = await service.generateHypotheticalDocument(query: "what is X?")

        XCTAssertEqual(result, "Reasoning-based answer", "应支持 reasoning_content 字段")
    }
}

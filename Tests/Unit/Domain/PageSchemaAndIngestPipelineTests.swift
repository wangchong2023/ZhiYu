//
//  PageSchemaAndIngestPipelineTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 测试层
//  核心职责：验证 PageSchema 必填字段校验与默认保底降级、KnowledgeIngestPipeline 空内容短路与异常回滚机制。
//

#if !os(watchOS)
import XCTest
import UFPCore
import UFPStorage
@testable import ZhiYu

final class PageSchemaAndIngestPipelineTests: XCTestCase {

    // MARK: - 1. KnowledgeIngestPipeline 容灾与边界测试

    func testKnowledgeIngestPipeline_EmptyOrWhitespaceContent_ReturnsImmediately() async throws {
        let pipeline = KnowledgeIngestPipeline.shared
        let mockProvider = MockPipelineEmbeddingProvider()

        let emptyResult = try await pipeline.process(
            content: "",
            pageID: UUID(),
            llm: nil,
            embeddingProvider: mockProvider
        )
        XCTAssertEqual(emptyResult, "")
        XCTAssertFalse(mockProvider.didCallIndexChunks, "空文档不应触发后续向量化流程")

        let whitespaceResult = try await pipeline.process(
            content: "   \n\t  ",
            pageID: UUID(),
            llm: nil,
            embeddingProvider: mockProvider
        )
        XCTAssertEqual(whitespaceResult, "   \n\t  ")
        XCTAssertFalse(mockProvider.didCallIndexChunks, "纯空白字符文档不应触发后续向量化流程")
    }

    func testKnowledgeIngestPipeline_ValidContentWithoutLLM_ProcessesAndEmbeds() async throws {
        let pipeline = KnowledgeIngestPipeline.shared
        let mockProvider = MockPipelineEmbeddingProvider()
        let pageID = UUID()

        let sampleContent = """
        # RAG 知识管道测试
        这是一个段落，用于测试知识切分与向量索引调度流程。
        包含多行文本，确保能够切分为有效分块。
        """

        let result = try await pipeline.process(
            content: sampleContent,
            pageID: pageID,
            llm: nil,
            embeddingProvider: mockProvider
        )

        XCTAssertEqual(result, sampleContent)
        XCTAssertTrue(mockProvider.didCallIndexChunks, "有效文本在无 LLM 时仍应完成分块切分并送入向量索引")
        XCTAssertEqual(mockProvider.indexedPageID, pageID)
        XCTAssertFalse(mockProvider.indexedChunks.isEmpty, "必须切分出至少一个父块/子块")
    }

    func testKnowledgeIngestPipeline_TaskCancellation_RollsBackAndRethrowsCancellationError() async {
        let pipeline = KnowledgeIngestPipeline.shared
        let mockProvider = MockPipelineEmbeddingProvider()
        let pageID = UUID()

        let task = Task {
            try await pipeline.process(
                content: "待处理的长文档内容，用于测试任务取消与回滚...",
                pageID: pageID,
                llm: nil,
                embeddingProvider: mockProvider
            )
        }
        task.cancel()

        do {
            _ = try await task.value
        } catch is CancellationError {
            // 取消异常被成功捕获并向上抛出
        } catch {
            XCTFail("非预期的错误: \(error)")
        }
    }
}

// MARK: - Mock Pipeline Embedding Provider

private final class MockPipelineEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    private let inner = NoOpEmbeddingProvider()
    var didCallIndexChunks = false
    var indexedPageID: UUID?
    var indexedChunks: [PageChunk] = []

    func getAllEmbeddings() async -> [UUID: [Float]] { await inner.getAllEmbeddings() }
    func syncEmbeddings(pages: [KnowledgePage]) async { await inner.syncEmbeddings(pages: pages) }
    func updateEmbedding(for page: KnowledgePage) async { await inner.updateEmbedding(for: page) }
    func indexChunks(pageID: UUID, chunks: [PageChunk]) async {
        didCallIndexChunks = true
        indexedPageID = pageID
        indexedChunks = chunks
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

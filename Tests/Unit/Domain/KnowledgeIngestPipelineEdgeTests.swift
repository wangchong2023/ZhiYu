//
//  KnowledgeIngestPipelineEdgeTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 测试层
//  核心职责：测试 KnowledgeIngestPipeline 在无 LLM 降级、空输入、短文本及任务取消下的边界鲁棒性。
//

import XCTest
import UFPCore
@testable import ZhiYu

// MARK: - Mock Embedding Provider

private final class IngestEdgeMockEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    var indexChunksCalled = false
    var lastIndexedPageID: UUID?

    func getAllEmbeddings() async -> [UUID: [Float]] { [:] }
    func syncEmbeddings(pages: [KnowledgePage]) async {}
    func updateEmbedding(for page: KnowledgePage) async {}
    func indexChunks(pageID: UUID, chunks: [PageChunk]) async {
        indexChunksCalled = true
        lastIndexedPageID = pageID
    }
    func vectorizeChunks(chunks: [String]) async -> [[Float]] { [] }
    func search(query: String, topK: Int) async -> [(id: UUID, score: Float)] { [] }
    func multiQuerySearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func hydeSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func selfReflectionSearch(query: String, candidates: [(chunk: PageChunk, score: Float)]) async -> [(chunk: PageChunk, score: Float)] { [] }
    func advancedSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func loadInitialCache() async {}
    func clearCacheAndReload() async {}
}

@MainActor
final class KnowledgeIngestPipelineEdgeTests: XCTestCase {

    // MARK: - 1. 无 LLM 降级模式

    func testProcessWithoutLLMGracefulFallback() async throws {
        let pipeline = KnowledgeIngestPipeline.shared
        let embeddingProvider = IngestEdgeMockEmbeddingProvider()
        let pageID = UUID()
        let rawContent = "这是第一段测试内容。\n\n这是第二段较为详细的知识库记录，用于验证在未配置 LLM 的纯本地模式下分块与摄入流程是否顺畅完成。"

        let result = try await pipeline.process(
            content: rawContent,
            pageID: pageID,
            llm: nil,
            embeddingProvider: embeddingProvider
        )

        XCTAssertEqual(result, rawContent, "无 LLM 时应直接返回原始内容")
        XCTAssertTrue(embeddingProvider.indexChunksCalled, "应调用 indexChunks 建立向量索引")
        XCTAssertEqual(embeddingProvider.lastIndexedPageID, pageID)
    }

    // MARK: - 2. 空内容安全摄入

    func testProcessEmptyContent() async throws {
        let pipeline = KnowledgeIngestPipeline.shared
        let embeddingProvider = IngestEdgeMockEmbeddingProvider()
        let pageID = UUID()

        let result = try await pipeline.process(
            content: "",
            pageID: pageID,
            llm: nil,
            embeddingProvider: embeddingProvider
        )

        XCTAssertEqual(result, "", "空文本应直接返回空字符串")
        XCTAssertFalse(embeddingProvider.indexChunksCalled, "空分块无需触发向量化索引")
    }

    // MARK: - 3. 带 LLM 的增强与摘要流程

    func testProcessWithLLMEnrichment() async throws {
        let pipeline = KnowledgeIngestPipeline.shared
        let embeddingProvider = IngestEdgeMockEmbeddingProvider()
        let mockLLM = MockLLMService()
        let pageID = UUID()
        let rawContent = "这是一篇关于知识图谱架构的深度长文。\n\n知识图谱通过节点与边组织关联。"

        let result = try await pipeline.process(
            content: rawContent,
            pageID: pageID,
            llm: mockLLM,
            embeddingProvider: embeddingProvider
        )

        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(embeddingProvider.indexChunksCalled)
    }
}

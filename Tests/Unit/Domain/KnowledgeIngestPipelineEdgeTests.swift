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
@testable import ZhiYuUnitTestHost

// MARK: - Mock Embedding Provider

private final class IngestEdgeMockEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    var indexChunksCalled = false
    var lastIndexedPageID: UUID?
    var lastIndexedChunks: [PageChunk] = []

    func getAllEmbeddings() async -> [UUID: [Float]] { [:] }
    func syncEmbeddings(pages: [KnowledgePage]) async {}
    func updateEmbedding(for page: KnowledgePage) async {}
    func indexChunks(pageID: UUID, chunks: [PageChunk]) async {
        indexChunksCalled = true
        lastIndexedPageID = pageID
        lastIndexedChunks = chunks
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

    // MARK: - 缺陷 #238 回归：空白拦截、子块全局偏移与取消传播

    func testProcess_whitespaceOnlyContent_skipsIndexing() async throws {
        let pipeline = KnowledgeIngestPipeline.shared
        let embeddingProvider = IngestEdgeMockEmbeddingProvider()
        let whitespace = "   \n\t\n   "

        let result = try await pipeline.process(
            content: whitespace,
            pageID: UUID(),
            llm: nil,
            embeddingProvider: embeddingProvider
        )

        XCTAssertEqual(result, whitespace)
        XCTAssertFalse(embeddingProvider.indexChunksCalled, "纯空白内容不应触发向量索引")
    }

    func testProcess_multiParentChunks_childStartIndexUsesGlobalOffset() async throws {
        let pipeline = KnowledgeIngestPipeline.shared
        let embeddingProvider = IngestEdgeMockEmbeddingProvider()
        // 构造超过 1000 字符的多段长文，确保切分出至少 2 个父块
        let paragraph = String(repeating: "知识图谱与语义检索系统架构设计说明。", count: 40)
        let longContent = [paragraph, paragraph, paragraph].joined(separator: "\n\n")

        _ = try await pipeline.process(
            content: longContent,
            pageID: UUID(),
            llm: nil,
            embeddingProvider: embeddingProvider
        )

        let parents = embeddingProvider.lastIndexedChunks.filter { $0.chunkType == .regular }
        let children = embeddingProvider.lastIndexedChunks.filter { $0.chunkType == .child }
        XCTAssertGreaterThanOrEqual(parents.count, 2, "长文应切分出多个父块")

        let laterParents = parents.filter { $0.startIndex > 0 }
        XCTAssertFalse(laterParents.isEmpty, "后续父块应具有大于 0 的全局起始偏移")

        for parent in laterParents {
            let ownChildren = children.filter { $0.parentID == parent.id }
            XCTAssertFalse(ownChildren.isEmpty, "每个父块应生成至少一个子块")
            for child in ownChildren {
                XCTAssertGreaterThanOrEqual(
                    child.startIndex,
                    parent.startIndex,
                    "子块 startIndex 必须为文档全局偏移（>= 所属父块 startIndex），而非相对 0 的局部偏移"
                )
            }
        }
    }

    func testProcess_cancelledTask_throwsCancellationAndSkipsIndexing() async {
        let pipeline = KnowledgeIngestPipeline.shared
        let embeddingProvider = IngestEdgeMockEmbeddingProvider()
        let content = "这是一段用于验证任务取消语义的测试正文。"

        let task = Task<String, Error> {
            try await pipeline.process(
                content: content,
                pageID: UUID(),
                llm: nil,
                embeddingProvider: embeddingProvider
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("已取消的摄入任务应抛出 CancellationError")
        } catch is CancellationError {
            XCTAssertFalse(embeddingProvider.indexChunksCalled, "取消后严禁以残缺分块覆写向量索引")
        } catch {
            XCTFail("应抛出 CancellationError，实际抛出: \(error)")
        }
    }
}

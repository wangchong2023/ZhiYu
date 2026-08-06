//
//  VectorIndexerTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 VectorIndexer 的空 chunks guard 与委托转发逻辑。
//

import XCTest
@testable import ZhiYu

final class VectorIndexerTests: XCTestCase {

    // MARK: - 空 chunks guard

    func testIndex_emptyChunks_doesNotCallProvider() async {
        let mock = MockEmbeddingProvider()
        let indexer = VectorIndexer(embeddingProvider: mock)

        await indexer.index(pageID: UUID(), chunks: [])

        XCTAssertEqual(mock.indexChunksCallCount, 0)
    }

    func testIndex_nonEmptyChunks_callsProvider() async {
        let mock = MockEmbeddingProvider()
        let indexer = VectorIndexer(embeddingProvider: mock)

        let pageID = UUID()
        let chunks = [
            PageChunk(id: "chunk_0", pageID: pageID, content: "Hello", index: 0),
            PageChunk(id: "chunk_1", pageID: pageID, content: "World", index: 1)
        ]

        await indexer.index(pageID: pageID, chunks: chunks)

        XCTAssertEqual(mock.indexChunksCallCount, 1)
        XCTAssertEqual(mock.lastPageID, pageID)
        XCTAssertEqual(mock.lastChunks?.count, 2)
    }

    func testIndex_singleChunk_callsProvider() async {
        let mock = MockEmbeddingProvider()
        let indexer = VectorIndexer(embeddingProvider: mock)

        let pageID = UUID()
        let chunk = PageChunk(id: "chunk_0", pageID: pageID, content: "Single", index: 0)

        await indexer.index(pageID: pageID, chunks: [chunk])

        XCTAssertEqual(mock.indexChunksCallCount, 1)
        XCTAssertEqual(mock.lastChunks?.count, 1)
    }

    func testIndex_passesCorrectPageID() async {
        let mock = MockEmbeddingProvider()
        let indexer = VectorIndexer(embeddingProvider: mock)

        let pageID = UUID()
        let chunk = PageChunk(id: "chunk_0", pageID: pageID, content: "Test", index: 0)

        await indexer.index(pageID: pageID, chunks: [chunk])

        XCTAssertEqual(mock.lastPageID, pageID)
    }

    func testIndex_passesCorrectChunkContent() async {
        let mock = MockEmbeddingProvider()
        let indexer = VectorIndexer(embeddingProvider: mock)

        let pageID = UUID()
        let chunks = [
            PageChunk(id: "c0", pageID: pageID, content: "Alpha", index: 0),
            PageChunk(id: "c1", pageID: pageID, content: "Beta", index: 1)
        ]

        await indexer.index(pageID: pageID, chunks: chunks)

        XCTAssertEqual(mock.lastChunks?[0].content, "Alpha")
        XCTAssertEqual(mock.lastChunks?[1].content, "Beta")
    }

    func testIndex_multipleCalls_eachCallForwarded() async {
        let mock = MockEmbeddingProvider()
        let indexer = VectorIndexer(embeddingProvider: mock)

        let pageID = UUID()
        let chunk = PageChunk(id: "c0", pageID: pageID, content: "Test", index: 0)

        await indexer.index(pageID: pageID, chunks: [chunk])
        await indexer.index(pageID: pageID, chunks: [chunk])
        await indexer.index(pageID: pageID, chunks: [chunk])

        XCTAssertEqual(mock.indexChunksCallCount, 3)
    }
}

// MARK: - Mock EmbeddingProvider

private final class MockEmbeddingProvider: EmbeddingProvider {
    var indexChunksCallCount = 0
    var lastPageID: UUID?
    var lastChunks: [PageChunk]?

    func getAllEmbeddings() async -> [UUID: [Float]] { [:] }
    func syncEmbeddings(pages: [KnowledgePage]) async {}
    func updateEmbedding(for page: KnowledgePage) async {}

    func indexChunks(pageID: UUID, chunks: [PageChunk]) async {
        indexChunksCallCount += 1
        lastPageID = pageID
        lastChunks = chunks
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

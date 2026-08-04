//
//  VectorDataRepositoryChunkTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 VectorDataRepository 的分块管理语义——先删后插非原子性、
//           孤儿分块清理、空向量保存、embedding 查询边界等。
//

import XCTest
import UFPStorage
@testable import ZhiYu

final class VectorDataChunkTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var vectorRepo: VectorDataRepository!
    var knowledgeRepo: KnowledgePageRepository!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        try await DatabaseManager.shared.setupForTesting(with: dbQueue)
        vectorRepo = VectorDataRepository(dbWriter: dbQueue)
        knowledgeRepo = KnowledgePageRepository(dbWriter: dbQueue)
    }

    override func tearDownWithError() throws {
        vectorRepo = nil
        knowledgeRepo = nil
        dbQueue = nil
    }

    // MARK: - saveChunks 先删后插语义

    /// 验证：saveChunks 先删除旧分块再插入新分块，重复调用不产生重复。
    func testSaveChunksReplacesExistingChunks() async throws {
        let pageID = UUID()
        // 先插入页面（外键约束）
        let page = KnowledgePage(title: "ChunkedPage", content: "content")
        try await knowledgeRepo.save(page)
        let actualPageID = try await knowledgeRepo.fetch(title: "ChunkedPage")?.id ?? pageID

        let chunk1 = PageChunk(
            id: "chunk-1",
            pageID: actualPageID,
            content: "第一段",
            index: 0
        )
        let chunk2 = PageChunk(
            id: "chunk-2",
            pageID: actualPageID,
            content: "第二段",
            index: 1
        )

        try await vectorRepo.saveChunks([chunk1, chunk2], for: actualPageID)
        var chunks = try await vectorRepo.fetchChunks(for: actualPageID)
        XCTAssertEqual(chunks.count, 2, "首次保存应有 2 个分块")

        // 重新保存不同分块
        let chunk3 = PageChunk(
            id: "chunk-3",
            pageID: actualPageID,
            content: "新段",
            index: 0
        )
        try await vectorRepo.saveChunks([chunk3], for: actualPageID)
        chunks = try await vectorRepo.fetchChunks(for: actualPageID)
        XCTAssertEqual(chunks.count, 1, "重新保存后旧分块应被删除，只保留新分块")
        XCTAssertEqual(chunks.first?.content, "新段")
    }

    /// 验证：saveChunks 保存空数组时清空已有分块。
    func testSaveEmptyChunksClearsExisting() async throws {
        let page = KnowledgePage(title: "EmptyChunks", content: "c")
        try await knowledgeRepo.save(page)
        let pageID = try await knowledgeRepo.fetch(title: "EmptyChunks")?.id ?? UUID()

        let chunk = PageChunk(id: "c1", pageID: pageID, content: "段", index: 0)
        try await vectorRepo.saveChunks([chunk], for: pageID)
        let countBefore = try await vectorRepo.fetchChunks(for: pageID).count
        XCTAssertEqual(countBefore, 1)

        // 保存空数组应清空
        try await vectorRepo.saveChunks([], for: pageID)
        let chunksAfter = try await vectorRepo.fetchChunks(for: pageID)
        XCTAssertTrue(chunksAfter.isEmpty, "空数组应清空已有分块")
    }

    // MARK: - deleteChunks 删除语义

    /// 验证：deleteChunks 删除指定页面的所有分块。
    func testDeleteChunksRemovesAllChunksForPage() async throws {
        let page = KnowledgePage(title: "DelChunks", content: "c")
        try await knowledgeRepo.save(page)
        let pageID = try await knowledgeRepo.fetch(title: "DelChunks")?.id ?? UUID()

        let chunks = [
            PageChunk(id: "d1", pageID: pageID, content: "a", index: 0),
            PageChunk(id: "d2", pageID: pageID, content: "b", index: 1)
        ]
        try await vectorRepo.saveChunks(chunks, for: pageID)

        try await vectorRepo.deleteChunks(for: pageID)
        let remaining = try await vectorRepo.fetchChunks(for: pageID)
        XCTAssertTrue(remaining.isEmpty, "deleteChunks 后应无分块")
    }

    /// 验证：deleteChunks 对不存在的 pageID 不报错。
    func testDeleteChunksForNonExistentPageIsNoop() async throws {
        let nonExistentID = UUID()
        try await vectorRepo.deleteChunks(for: nonExistentID)
        // 不应抛出异常
    }

    // MARK: - fetchAllChunksWithEmbeddings

    /// 验证：fetchAllChunksWithEmbeddings 只返回有 embedding 的分块。
    func testFetchAllChunksWithEmbeddingsFiltersEmpty() async throws {
        let page = KnowledgePage(title: "EmbedPage", content: "c")
        try await knowledgeRepo.save(page)
        let pageID = try await knowledgeRepo.fetch(title: "EmbedPage")?.id ?? UUID()

        let chunkWithEmbedding = PageChunk(
            id: "with-embed",
            pageID: pageID,
            content: "有向量",
            index: 0,
            embedding: Data([0x01, 0x02, 0x03])
        )
        let chunkWithoutEmbedding = PageChunk(
            id: "no-embed",
            pageID: pageID,
            content: "无向量",
            index: 1,
            embedding: nil
        )

        try await vectorRepo.saveChunks([chunkWithEmbedding, chunkWithoutEmbedding], for: pageID)

        let withEmbeddings = try await vectorRepo.fetchAllChunksWithEmbeddings()
        XCTAssertEqual(withEmbeddings.count, 1, "只应返回有 embedding 的分块")
        XCTAssertEqual(withEmbeddings.first?.id, "with-embed")
    }

    /// 验证：无任何分块有 embedding 时返回空数组。
    func testFetchAllChunksWithEmbeddingsEmptyWhenNone() async throws {
        let page = KnowledgePage(title: "NoEmbed", content: "c")
        try await knowledgeRepo.save(page)
        let pageID = try await knowledgeRepo.fetch(title: "NoEmbed")?.id ?? UUID()

        let chunk = PageChunk(id: "c", pageID: pageID, content: "x", index: 0, embedding: nil)
        try await vectorRepo.saveChunks([chunk], for: pageID)

        let result = try await vectorRepo.fetchAllChunksWithEmbeddings()
        XCTAssertTrue(result.isEmpty, "无 embedding 的分块不应被返回")
    }

    // MARK: - cleanupOrphanedChunks

    /// 验证：cleanupOrphanedChunks 删除不属于任何页面的孤儿分块。
    func testCleanupOrphanedChunksRemovesOrphans() async throws {
        let page = KnowledgePage(title: "KeepPage", content: "c")
        try await knowledgeRepo.save(page)
        let pageID = try await knowledgeRepo.fetch(title: "KeepPage")?.id ?? UUID()

        // 保存属于页面的分块
        let validChunk = PageChunk(id: "valid", pageID: pageID, content: "有效", index: 0)
        try await vectorRepo.saveChunks([validChunk], for: pageID)

        // 直接写入一个孤儿分块（pageID 不存在），需在事务外关闭外键约束
        try await dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA foreign_keys = OFF")
            try db.execute(sql: """
                INSERT INTO page_chunks (id, page_id, parent_id, chunk_type, content, anchor_path,
                                         chunk_index, start_index, embedding, created_at, updated_at)
                VALUES ('orphan', '00000000-0000-0000-0000-000000000000', NULL, 'regular',
                        '孤儿', NULL, 0, 0, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """)
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        let deletedCount = try await vectorRepo.cleanupOrphanedChunks()
        XCTAssertEqual(deletedCount, 1, "应删除 1 个孤儿分块")

        let remaining = try await vectorRepo.fetchChunks(for: pageID)
        XCTAssertEqual(remaining.count, 1, "有效分块应保留")
        XCTAssertEqual(remaining.first?.id, "valid")
    }

    /// 验证：无孤儿分块时 cleanupOrphanedChunks 返回 0。
    func testCleanupOrphanedChunksReturnsZeroWhenClean() async throws {
        let page = KnowledgePage(title: "Clean", content: "c")
        try await knowledgeRepo.save(page)
        let pageID = try await knowledgeRepo.fetch(title: "Clean")?.id ?? UUID()

        let chunk = PageChunk(id: "c", pageID: pageID, content: "x", index: 0)
        try await vectorRepo.saveChunks([chunk], for: pageID)

        let deletedCount = try await vectorRepo.cleanupOrphanedChunks()
        XCTAssertEqual(deletedCount, 0, "无孤儿分块时应返回 0")
    }

    // MARK: - saveEmbedding / fetchAllEmbeddings

    /// 验证：saveEmbedding 保存向量并可通过 fetchAllEmbeddings 检索。
    func testSaveAndFetchEmbedding() async throws {
        let page = KnowledgePage(title: "EmbedPage1", content: "c")
        try await knowledgeRepo.save(page)
        let pageID = try await knowledgeRepo.fetch(title: "EmbedPage1")?.id ?? UUID()
        let vector: [Float] = [0.1, 0.2, 0.3, 0.4]

        try await vectorRepo.saveEmbedding(id: pageID, vector: vector, modelName: "test-model")

        let allEmbeddings = try await vectorRepo.fetchAllEmbeddings()
        XCTAssertEqual(allEmbeddings[pageID]?.count, 4, "应检索到 4 维向量")
        XCTAssertEqual(allEmbeddings[pageID]?[0] ?? 0, 0.1, accuracy: 0.001)
    }

    /// 验证：saveEmbedding 对同一 pageID 重复保存应覆盖（upsert 语义）。
    func testSaveEmbeddingOverwritesExisting() async throws {
        let page = KnowledgePage(title: "EmbedPage2", content: "c")
        try await knowledgeRepo.save(page)
        let pageID = try await knowledgeRepo.fetch(title: "EmbedPage2")?.id ?? UUID()
        try await vectorRepo.saveEmbedding(id: pageID, vector: [1.0, 2.0], modelName: "m1")
        try await vectorRepo.saveEmbedding(id: pageID, vector: [3.0, 4.0, 5.0], modelName: "m2")

        let allEmbeddings = try await vectorRepo.fetchAllEmbeddings()
        XCTAssertEqual(allEmbeddings.count, 1, "同一 pageID 应只有一条记录")
        XCTAssertEqual(allEmbeddings[pageID]?.count, 3, "向量应被覆盖为 3 维")
    }

    /// 验证：保存空向量。
    func testSaveEmptyVectorEmbedding() async throws {
        let page = KnowledgePage(title: "EmbedPage3", content: "c")
        try await knowledgeRepo.save(page)
        let pageID = try await knowledgeRepo.fetch(title: "EmbedPage3")?.id ?? UUID()
        try await vectorRepo.saveEmbedding(id: pageID, vector: [], modelName: "empty")

        let allEmbeddings = try await vectorRepo.fetchAllEmbeddings()
        XCTAssertTrue(allEmbeddings[pageID]?.isEmpty ?? false, "空向量应能保存和检索")
    }

    /// 验证：fetchAllEmbeddings 在无数据时返回空字典。
    func testFetchAllEmbeddingsEmptyWhenNoData() async throws {
        let allEmbeddings = try await vectorRepo.fetchAllEmbeddings()
        XCTAssertTrue(allEmbeddings.isEmpty, "无数据时应返回空字典")
    }
}

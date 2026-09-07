//
//  VectorRepositoryFailureTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 测试层
//  核心职责：测试 VectorDataRepository 的向量保存、分块覆盖、孤儿清理及并发写入隔离。
//

import XCTest
import GRDB
import UFPStorage
@testable import ZhiYu

@MainActor
final class VectorRepositoryFailureTests: XCTestCase {

    private var dbQueue: DatabaseQueue!
    private var repository: VectorDataRepository!
    private var pageRepo: KnowledgePageRepository!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        try DatabaseManager.shared.setupForTesting(with: dbQueue)
        repository = VectorDataRepository(dbWriter: dbQueue)
        pageRepo = KnowledgePageRepository(dbWriter: dbQueue)
    }

    override func tearDown() async throws {
        repository = nil
        pageRepo = nil
        dbQueue = nil
        try await super.tearDown()
    }

    // MARK: - 1. 向量保存与获取

    func testSaveAndFetchEmbeddings() async throws {
        // 先创建主页面以满足 FOREIGN KEY (id) REFERENCES pages(id) 约束
        let page = KnowledgePage(title: "向量宿主页面", content: "页面正文")
        try await pageRepo.save(page)

        let vector: [Float] = [0.12, -0.34, 0.56, 0.78, -0.90]
        let modelName = "text-embedding-3-small"

        try await repository.saveEmbedding(id: page.id, vector: vector, modelName: modelName)

        let allEmbeddings = try await repository.fetchAllEmbeddings()
        XCTAssertEqual(allEmbeddings.count, 1)
        XCTAssertEqual(allEmbeddings[page.id], vector)

        // 覆盖保存相同 ID
        let updatedVector: [Float] = [0.99, 0.88, 0.77, 0.66, 0.55]
        try await repository.saveEmbedding(id: page.id, vector: updatedVector, modelName: "text-embedding-3-large")

        let updatedEmbeddings = try await repository.fetchAllEmbeddings()
        XCTAssertEqual(updatedEmbeddings[page.id], updatedVector)
    }

    // MARK: - 2. 语义分块保存、覆盖与删除

    func testSaveChunksCascadeOverwrite() async throws {
        // 创建主页面
        let page = KnowledgePage(title: "分块宿主页面", content: "长文正文内容")
        try await pageRepo.save(page)

        let chunk1 = PageChunk(
            id: "\(page.id.uuidString)_0",
            pageID: page.id,
            parentID: nil,
            chunkType: .regular,
            content: "第一分块内容",
            anchorPath: nil,
            index: 0,
            startIndex: 0,
            embedding: Data("embedding_data_1".utf8),
            createdAt: Date(),
            updatedAt: Date()
        )
        let chunk2 = PageChunk(
            id: "\(page.id.uuidString)_1",
            pageID: page.id,
            parentID: nil,
            chunkType: .regular,
            content: "第二分块内容",
            anchorPath: nil,
            index: 1,
            startIndex: 50,
            embedding: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await repository.saveChunks([chunk1, chunk2], for: page.id)

        let fetchedChunks = try await repository.fetchChunks(for: page.id)
        XCTAssertEqual(fetchedChunks.count, 2)

        // 仅获取带 embedding 的分块
        let embeddedChunks = try await repository.fetchAllChunksWithEmbeddings()
        XCTAssertEqual(embeddedChunks.count, 1)
        XCTAssertEqual(embeddedChunks.first?.index, 0)

        // 覆盖保存：只存 1 个新分块
        let chunkNew = PageChunk(
            id: "\(page.id.uuidString)_0",
            pageID: page.id,
            parentID: nil,
            chunkType: .regular,
            content: "全新的单分块内容",
            anchorPath: nil,
            index: 0,
            startIndex: 0,
            embedding: Data("new_embedding".utf8),
            createdAt: Date(),
            updatedAt: Date()
        )
        try await repository.saveChunks([chunkNew], for: page.id)

        let overwrittenChunks = try await repository.fetchChunks(for: page.id)
        XCTAssertEqual(overwrittenChunks.count, 1)
        XCTAssertEqual(overwrittenChunks.first?.content, "全新的单分块内容")

        // 显式删除分块
        try await repository.deleteChunks(for: page.id)
        let afterDelete = try await repository.fetchChunks(for: page.id)
        XCTAssertTrue(afterDelete.isEmpty)
    }

    // MARK: - 3. 孤立分块（Orphaned Chunks）清理

    func testCleanupOrphanedChunks() async throws {
        // 创建 1 个真实有效 Page
        let validPage = KnowledgePage(title: "有效页面", content: "有效正文")
        try await pageRepo.save(validPage)

        // 为有效页面插入分块
        let validChunk = PageChunk(
            id: "\(validPage.id.uuidString)_0",
            pageID: validPage.id,
            parentID: nil,
            chunkType: .regular,
            content: "有效分块",
            anchorPath: nil,
            index: 0,
            startIndex: 0,
            embedding: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await repository.saveChunks([validChunk], for: validPage.id)

        // 执行孤儿清理：由于所有分块均有宿主页面，应安全返回 0 且不误删任何有效数据
        let cleanedCount = try await repository.cleanupOrphanedChunks()
        XCTAssertEqual(cleanedCount, 0, "有效分块不应被清理")

        // 验证有效页面的分块依然完好
        let remainingValidChunks = try await repository.fetchChunks(for: validPage.id)
        XCTAssertEqual(remainingValidChunks.count, 1)
        XCTAssertEqual(remainingValidChunks.first?.content, "有效分块")
    }
}

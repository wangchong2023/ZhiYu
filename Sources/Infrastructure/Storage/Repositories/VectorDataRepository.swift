//
//  VectorDataRepository.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：持久化引擎：GRDB/SQLite 仓库、同步、加密、数据库管理。
//
import Foundation
import UFPStorage

/// [Infra] 向量存储实现
final class VectorDataRepository: VectorRepository, DatabaseWriterProvider, Sendable {
    init(dbWriter _: any DatabaseWriter) {
        // 保留原构造函数，但内部实际上不持有静态 dbWriter，使用动态计算属性以支持多笔记本笔记本无缝热切换并消除 closed 连接挂起隐慢
    }

    // MARK: - 向量映射 (Embeddings)

    /// 保存Embedding
    /// - Parameter id: id
    /// - Parameter vector: vector
    /// - Parameter modelName: modelName
    func saveEmbedding(id: UUID, vector: [Float], modelName: String) async throws {
        let writer = try await dbWriter
        _ = try await writer.write { db in
            var entry = PageEmbedding(id: id, vector: vector, modelName: modelName)
            try entry.save(db)
        }
    }

    /// 拉取AllEmbeddings
    /// - Returns: 列表
    func fetchAllEmbeddings() async throws -> [UUID: [Float]] {
        let writer = try await dbWriter
        return try await writer.read { db in
            let records = try PageEmbedding.fetchAll(db)
            var dict: [UUID: [Float]] = [:]
            for record in records {
                dict[record.id] = record.vector
            }
            return dict
        }
    }

    // MARK: - 语义分块 (Chunks)

    /// 拉取Chunks
    /// - Returns: 列表
    func fetchChunks(for pageID: UUID) async throws -> [PageChunk] {
        let writer = try await dbWriter
        return try await writer.read { db in
            try PageChunk
                .filter(PageChunk.Columns.pageID == pageID)
                .fetchAll(db)
        }
    }

    /// 拉取AllChunksWithEmbeddings
    /// - Returns: 列表
    func fetchAllChunksWithEmbeddings() async throws -> [PageChunk] {
        let writer = try await dbWriter
        return try await writer.read { db in
            try PageChunk
                .filter(PageChunk.Columns.embedding != nil)
                .fetchAll(db)
        }
    }

    /// 保存Chunks
    /// - Parameter chunks: chunks
    func saveChunks(_ chunks: [PageChunk], for pageID: UUID) async throws {
        let writer = try await dbWriter
        _ = try await writer.write { db in
            // 物理删除旧分块，确保索引最新
            try deleteChunksByPageID(db: db, pageID: pageID)

            for var chunk in chunks {
                chunk.pageID = pageID
                chunk.createdAt = Date()
                chunk.updatedAt = Date()
                try chunk.insert(db)
            }
        }
    }

    /// 删除Chunks
    func deleteChunks(for pageID: UUID) async throws {
        let writer = try await dbWriter
        _ = try await writer.write { db in
            try deleteChunksByPageID(db: db, pageID: pageID)
        }
    }

    /// 按 pageID 删除分块（消除 saveChunks 与 deleteChunks 的删除样板重复）。
    private func deleteChunksByPageID(db: Database, pageID: UUID) throws {
        try PageChunk
            .filter(PageChunk.Columns.pageID == pageID)
            .deleteAll(db)
    }

    /// cleanupOrphanedChunks
    /// - Returns: 清理的孤儿分块总数
    func cleanupOrphanedChunks() async throws -> Int {
        let writer = try await dbWriter
        return try await writer.write { db in
            let pages = KnowledgePage.select(KnowledgePage.Columns.id)
            return try PageChunk
                .filter(!pages.contains(PageChunk.Columns.pageID))
                .deleteAll(db)
        }
    }
}

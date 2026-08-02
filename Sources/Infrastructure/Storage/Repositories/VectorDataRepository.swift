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
final class VectorDataRepository: VectorRepository, @unchecked Sendable {
    private var dbWriter: any DatabaseWriter {
        get async {
            // 直接 await @MainActor 属性，避免 MainActor.run 在 XCTest 并行 worker 中死锁
            if let writer = await DatabaseManager.shared.dbWriter {
                return writer
            }
            // DatabaseQueue() 创建在调用方 actor 上执行，不阻塞主线程
            do { return try DatabaseQueue() } catch { fatalError("无法创建内存数据库(VectorDataRepo): \(error)") }
        }
    }

    init(dbWriter: any DatabaseWriter) {
        // 保留原构造函数，但内部实际上不持有静态 dbWriter，使用动态计算属性以支持多笔记本笔记本无缝热切换并消除 closed 连接挂起隐慢
    }

    // MARK: - 向量映射 (Embeddings)

    /// 保存Embedding
    /// - Parameter id: id
    /// - Parameter vector: vector
    /// - Parameter modelName: modelName
    func saveEmbedding(id: UUID, vector: [Float], modelName: String) async throws {
        let writer = await dbWriter
        _ = try await writer.write { db in
            var entry = PageEmbedding(id: id, vector: vector, modelName: modelName)
            try entry.save(db)
        }
    }

    /// 拉取AllEmbeddings
    /// - Returns: 列表
    func fetchAllEmbeddings() async throws -> [UUID: [Float]] {
        let writer = await dbWriter
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
        let writer = await dbWriter
        return try await writer.read { db in
            try PageChunk
                .filter(PageChunk.Columns.pageID == pageID)
                .fetchAll(db)
        }
    }

    /// 拉取AllChunksWithEmbeddings
    /// - Returns: 列表
    func fetchAllChunksWithEmbeddings() async throws -> [PageChunk] {
        let writer = await dbWriter
        return try await writer.read { db in
            try PageChunk
                .filter(PageChunk.Columns.embedding != nil)
                .fetchAll(db)
        }
    }

    /// 保存Chunks
    /// - Parameter chunks: chunks
    func saveChunks(_ chunks: [PageChunk], for pageID: UUID) async throws {
        let writer = await dbWriter
        _ = try await writer.write { db in
            // 物理删除旧分块，确保索引最新
            try PageChunk
                .filter(PageChunk.Columns.pageID == pageID)
                .deleteAll(db)
            
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
        let writer = await dbWriter
        _ = try await writer.write { db in
            try PageChunk
                .filter(PageChunk.Columns.pageID == pageID)
                .deleteAll(db)
        }
    }

    /// cleanupOrphanedChunks
    /// - Returns: 数值
    func cleanupOrphanedChunks() async throws -> Int {
        let writer = await dbWriter
        return try await writer.write { db in
            // 使用 Query Interface 的 subquery 方式替代原始 SQL
            let pages = KnowledgePage.select(KnowledgePage.Columns.id)
            let deletedCount = try PageChunk
                .filter(!pages.contains(PageChunk.Columns.pageID))
                .deleteAll(db)
            return deletedCount
        }
    }
}

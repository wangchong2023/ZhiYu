//
//  RAGModels+GRDB.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：持久化引擎：GRDB/SQLite 仓库、同步、加密、数据库管理。
//
import UFPStorage
import Foundation

// MARK: - PageChunk GRDB 协议遵循
extension PageChunk: FetchableRecord, MutablePersistableRecord {}

// MARK: - PageChunk Database Schema
extension PageChunk {
    enum Columns {
        static let id = Column("id")
        static let pageID = Column("page_id")
        static let parentID = Column("parent_id")
        static let chunkType = Column("chunk_type")
        static let content = Column("content")
        static let anchorPath = Column("anchor_path")
        static let index = Column("chunk_index")
        static let startIndex = Column("start_index")
        static let embedding = Column("embedding")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}

// MARK: - PageEmbedding GRDB 协议遵循
extension PageEmbedding: FetchableRecord, MutablePersistableRecord {}

// MARK: - PageEmbedding Database Schema & 序列化
extension PageEmbedding {
    enum Columns {
        static let id = Column("id")
        static let vector = Column("vector_blob")
        static let modelName = Column("model_name")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }

    /// GRDB 编码
    public func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.modelName] = modelName
        let data = vector.withUnsafeBufferPointer { Data(buffer: $0) }
        container[Columns.vector] = data
    }

    public init(row: Row) throws {
        id = row[Columns.id]
        modelName = row[Columns.modelName]
        let data: Data = row[Columns.vector]
        vector = data.withUnsafeBytes { pointer in
            Array(UnsafeBufferPointer(start: pointer.baseAddress?.assumingMemoryBound(to: Float.self), count: data.count / MemoryLayout<Float>.size))
        }
    }
}

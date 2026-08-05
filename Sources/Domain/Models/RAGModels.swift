//
//  RAGModels.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义 RAG 检索增强生成领域模型：页面分块 (PageChunk)、嵌入向量及混合检索召回结果。
//
import Foundation

/// 知识分块模型：用于 RAG 检索的原子单位
public struct PageChunk: Identifiable, Codable, Sendable {
    public static let databaseTableName: String = AppConstants.Storage.Tables.pageChunks
    
    public var id: String        // 格式: pageID_index 或特定前缀
    public var pageID: UUID
    public var parentID: String?  // 父块 ID (用于层级索引)
    public var chunkType: ChunkType  // 分块类型枚举（regular/summary/child/qa_pair/paragraph/text）
    public var content: String
    public var anchorPath: String? // 语义层级路径 (例如: " > ")
    public var index: Int         // 排序索引
    public var startIndex: Int    // 在原始文本中的偏移量
    public var embedding: Data?   // 序列化的向量数据
    public var createdAt: Date
    public var updatedAt: Date
    
    public enum CodingKeys: String, CodingKey {
        case id
        case pageID = "page_id"
        case parentID = "parent_id"
        case chunkType = "chunk_type"
        case content
        case anchorPath = "anchor_path"
        case index = "chunk_index"
        case startIndex = "start_index"
        case embedding
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String,
        pageID: UUID,
        parentID: String? = nil,
        chunkType: ChunkType = .regular,
        content: String,
        anchorPath: String? = nil,
        index: Int,
        startIndex: Int = 0,
        embedding: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.pageID = pageID
        self.parentID = parentID
        self.chunkType = chunkType
        self.content = content
        self.anchorPath = anchorPath
        self.index = index
        self.startIndex = startIndex
        self.embedding = embedding
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// 页面级向量映射模型
public struct PageEmbedding: Identifiable, Codable, Sendable {
    public static let databaseTableName: String = AppConstants.Storage.Tables.pageEmbeddings
    
    public var id: UUID          // 对应 KnowledgePage.id
    public var vector: [Float]
    public var modelName: String
    
    public init(id: UUID, vector: [Float], modelName: String) {
        self.id = id
        self.vector = vector
        self.modelName = modelName
    }
    
}

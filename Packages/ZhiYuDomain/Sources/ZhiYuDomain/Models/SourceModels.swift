//
//  SourceModels.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义知识来源 (KnowledgeSource) 的领域模型，关联原文页面 ID、标题及来源元数据。
//
import Foundation

/// AI 引用信源模型
public struct KnowledgeSource: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let pageID: UUID      // 关联的原文页面 ID
    public let title: String     // 页面标题
    public let snippet: String   // 引用的文本片段
    public let anchorPath: String? // 语义路径 (如: " > ")
    public let score: Double     // 相似度或置信度分数 (0.0 - 1.0)
    public let timestamp: Date
    
    public init(id: UUID = UUID(), pageID: UUID, title: String, snippet: String, anchorPath: String? = nil, score: Double, timestamp: Date = Date()) {
        self.id = id
        self.pageID = pageID
        self.title = title
        self.snippet = snippet
        self.anchorPath = anchorPath
        self.score = score
        self.timestamp = timestamp
    }
}

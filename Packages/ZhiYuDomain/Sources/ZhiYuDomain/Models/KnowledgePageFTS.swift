//
//  KnowledgePageFTS.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义全文搜索 (FTS5) 虚拟表的领域模型，映射 KnowledgePage 标题与内容可搜索字段。
//
import Foundation

/// 全文搜索索引模型 (FTS5)
public struct KnowledgePageFTS: Codable, Sendable {
    
    public var id: String
    public var title: String
    public var content: String
    public var tags: String?
    public var aliases: String?
    
    public init(id: String, title: String, content: String, tags: String? = nil, aliases: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.aliases = aliases
    }
}

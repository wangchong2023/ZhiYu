//
//  PluginRecordFTS.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：插件 FTS5 全文搜索虚拟表模型，支持按名称、作者快速检索。
//
import Foundation

/// 插件 FTS5 全文搜索索引模型
public struct PluginRecordFTS: Codable, Sendable {
    public var id: String
    public var name: String
    public var author: String
    public var description: String

    public enum CodingKeys: String, CodingKey {
        case id, name, author, description
    }

    public init(id: String, name: String, author: String, description: String) {
        self.id = id
        self.name = name
        self.author = author
        self.description = description
    }
}

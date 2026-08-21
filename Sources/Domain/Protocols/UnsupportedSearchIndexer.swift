//
//  UnsupportedSearchIndexer.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：平台不支持功能的安全桩实现，遵循协议提供空操作或未实现提示。
//
import Foundation

/// 不支持搜索索引的平台实现（测试/预览占位，平台无搜索能力时降级）
public final class UnsupportedSearchIndexer: SearchIndexerProtocol, Sendable {

    /// 索引Page
    /// - Parameter page: page
    public func indexPage(_ page: KnowledgePage) {}

    /// 索引Pages
    /// - Parameter pages: pages
    public func indexPages(_ pages: [KnowledgePage]) {}

    /// 移除索引
    public func removeIndex(for pageID: UUID) {}

    /// 取消索引All
    public func deindexAll() {}

    /// reindexAll
    /// - Parameter pages: pages
    public func reindexAll(pages: [KnowledgePage]) {}
}

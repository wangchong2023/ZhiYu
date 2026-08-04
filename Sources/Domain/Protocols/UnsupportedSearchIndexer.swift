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

/// 不支持搜索索引的平台实现
final class UnsupportedSearchIndexer: SearchIndexerProtocol, Sendable {

    /// 索引Page
    /// - Parameter page: page
    func indexPage(_ page: KnowledgePage) {}

    /// 索引Pages
    /// - Parameter pages: pages
    func indexPages(_ pages: [KnowledgePage]) {}

    /// 移除索引
    func removeIndex(for pageID: UUID) {}

    /// 取消索引All
    func deindexAll() {}

    /// reindexAll
    /// - Parameter pages: pages
    func reindexAll(pages: [KnowledgePage]) {}
}

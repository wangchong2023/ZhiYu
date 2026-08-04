//
//  SpotlightService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 Spotlight 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore

/// Spotlight 索引服务 (Expert Design Item #3)
/// 负责协调底层平台的系统搜索索引实现。
@MainActor
final class SpotlightService {
    static let shared = SpotlightService()
    
    @Inject private var indexer: any SearchIndexerProtocol
    
    private init() {}
    
    /// 索引单张页面
    func indexPage(_ page: KnowledgePage) {
        indexer.indexPage(page)
    }
    
    /// 批量索引页面
    func indexPages(_ pages: [KnowledgePage]) {
        indexer.indexPages(pages)
    }
    
    /// 移除页面索引
    func removeIndex(for pageID: UUID) {
        indexer.removeIndex(for: pageID)
    }
    
    /// 移除所有页面索引
    func deindexAll() {
        indexer.deindexAll()
    }
    
    /// 全量重新索引
    func reindexAll(pages: [KnowledgePage]) {
        indexer.reindexAll(pages: pages)
    }
}

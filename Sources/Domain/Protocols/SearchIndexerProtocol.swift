//
//  SearchIndexerProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义 SearchIndexer 模块的抽象契约接口。
//
import Foundation

/// 搜索索引服务协议
public protocol SearchIndexerProtocol: Sendable {
    /// 索引单张页面
    func indexPage(_ page: KnowledgePage)
    
    /// 批量索引页面
    func indexPages(_ pages: [KnowledgePage])
    
    /// 移除页面索引
    func removeIndex(for pageID: UUID)
    
    /// 移除所有页面索引
    func deindexAll()
    
    /// 全量重新索引
    func reindexAll(pages: [KnowledgePage])
}

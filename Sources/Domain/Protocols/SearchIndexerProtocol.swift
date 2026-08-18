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
import Dependencies
import UFPCore

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

// MARK: - DependencyKey 注册

/// SearchIndexerProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum SearchIndexerKey: DependencyKey {
    public static var liveValue: any SearchIndexerProtocol {
        ServiceContainer.shared.resolveOptional((any SearchIndexerProtocol).self) ?? UnsupportedSearchIndexer()
    }
    public static var testValue: any SearchIndexerProtocol {
        ServiceContainer.shared.resolveOptional((any SearchIndexerProtocol).self) ?? UnsupportedSearchIndexer()
    }
    public static var previewValue: any SearchIndexerProtocol { UnsupportedSearchIndexer() }
}

extension DependencyValues {
    /// 搜索索引服务依赖
    public var searchIndexer: any SearchIndexerProtocol {
        get { self[SearchIndexerKey.self] }
        set { self[SearchIndexerKey.self] = newValue }
    }
}

//
//  iOSSpotlightIndexer.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台实现：后台任务、Widget、文件归档、Spotlight 索引。
//
#if canImport(CoreSpotlight)
import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// iOS/macOS Spotlight 索引实现
final class iOSSpotlightIndexer: SearchIndexerProtocol, Sendable {

    /// 索引Page
    /// - Parameter page: page
    func indexPage(_ page: KnowledgePage) {
        indexPages([page])
    }
    
    /// 索引Pages
    /// - Parameter pages: pages
    func indexPages(_ pages: [KnowledgePage]) {
        var searchableItems: [CSSearchableItem] = []
        
        for page in pages {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .plainText)
            attributeSet.title = page.title
            attributeSet.contentDescription = String(page.content.prefix(200))
            attributeSet.keywords = page.tags + page.aliases
            attributeSet.relatedUniqueIdentifier = page.id.uuidString
            
            let item = CSSearchableItem(
                uniqueIdentifier: page.id.uuidString,
                domainIdentifier: "com.zhiyu.app.pages",
                attributeSet: attributeSet
            )
            item.expirationDate = nil
            searchableItems.append(item)
        }
        
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if error != nil {
                Logger.shared.error("Spotlight_Error")
            }
        }
    }
    
    /// 移除索引
    func removeIndex(for pageID: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [pageID.uuidString]) { _ in }
    }
    
    /// 取消索引All
    func deindexAll() {
        CSSearchableIndex.default().deleteAllSearchableItems { _ in }
    }
    
    /// reindexAll
    /// - Parameter pages: pages
    func reindexAll(pages: [KnowledgePage]) {
        CSSearchableIndex.default().deleteAllSearchableItems { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.indexPages(pages)
            }
        }
    }
}
#endif

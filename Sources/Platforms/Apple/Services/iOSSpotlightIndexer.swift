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
    
    /// Spotlight 索引分区结果：公开页待索引项 + 私密页待撤销 ID
    internal struct IndexingPartition {
        let items: [CSSearchableItem]
        let privateIDs: [String]
    }

    /// 将页面按隐私级别拆分为可索引的 Spotlight 项与需撤销的私密页面 ID（防御私密笔记明文泄露）
    internal static func partitionPagesForIndexing(_ pages: [KnowledgePage]) -> IndexingPartition {
        var searchableItems: [CSSearchableItem] = []
        var privateIDs: [String] = []

        for page in pages {
            if page.isPrivate {
                privateIDs.append(page.id.uuidString)
                continue
            }

            let attributeSet = CSSearchableItemAttributeSet(contentType: .plainText)
            attributeSet.title = page.title
            // Bug #51 修复：魔鬼数字 200 抽取为常量
            attributeSet.contentDescription = String(page.content.prefix(PlatformConstants.Spotlight.contentDescriptionMaxLength))
            attributeSet.keywords = page.tags + page.aliases
            attributeSet.relatedUniqueIdentifier = page.id.uuidString

            let item = CSSearchableItem(
                uniqueIdentifier: page.id.uuidString,
                // Bug #52 修复：魔鬼字符串抽取为常量
                domainIdentifier: PlatformConstants.Spotlight.domainIdentifier,
                attributeSet: attributeSet
            )
            item.expirationDate = nil
            searchableItems.append(item)
        }

        return IndexingPartition(items: searchableItems, privateIDs: privateIDs)
    }

    /// 索引Pages
    /// - Parameter pages: pages
    func indexPages(_ pages: [KnowledgePage]) {
        guard !pages.isEmpty else { return }
        let partition = Self.partitionPagesForIndexing(pages)

        if !partition.privateIDs.isEmpty {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: partition.privateIDs) { _ in }
        }

        guard !partition.items.isEmpty else { return }
        CSSearchableIndex.default().indexSearchableItems(partition.items) { error in
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

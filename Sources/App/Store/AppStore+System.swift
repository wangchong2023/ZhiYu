//
//  AppStore+System.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：AppStore 的系统协议实现 — AnyPageStore 全量接口适配与 GraphDataProvider 桥接。
//
import SwiftUI
import UFPStorage

// MARK: - AnyPageStore 协议实现

@MainActor
extension AppStore: AnyPageStore {

    /// 拉取AllPages
    public func fetchAllPages() async throws -> [KnowledgePage] {
        await knowledgeStore.refresh()
        return knowledgeStore.pages
    }

    /// reloadFromDisk
    public func reloadFromDisk() async {
        await knowledgeStore.loadFromDisk()
    }

    /// 替换AllPages
    public func replaceAllPages(_ newPages: [KnowledgePage]) async {
        await knowledgeStore.saveToDisk()
        await pageStore.replaceAllPages(newPages)
        await knowledgeStore.refresh()
    }

    /// 重置Database
    public func resetDatabase() async throws {
        try await pageStore.resetDatabase()
        await knowledgeStore.refresh()
    }

    /// 执行BatchWrite
    public func performBatchWrite(_ block: @escaping @Sendable (Database) throws -> Void) async throws {
        try await pageStore.performBatchWrite(block)
        await knowledgeStore.refresh()
    }

    /// 创建Page
    public func createPage(
        title: String,
        pageType: PageType,
        customIcon: String?,
        content: String,
        tags: [String],
        sourceURL: String?,
        rawSnippet: String?,
        fileSize: Int64?,
        sourceType: String?
    ) async throws -> KnowledgePage {
        await knowledgeStore.createPage(
            title: title,
            pageType: pageType,
            customIcon: customIcon,
            content: content,
            tags: tags,
            sourceURL: sourceURL,
            rawSnippet: rawSnippet,
            fileSize: fileSize,
            sourceType: sourceType
        )
    }

    /// any创建Page
    public func anyCreatePage(
        title: String,
        pageType: PageType,
        customIcon: String?,
        content: String,
        tags: [String],
        sourceURL: String?,
        rawSnippet: String?,
        fileSize: Int64?,
        sourceType: String?,
        forceDeepScan: Bool
    ) async -> KnowledgePage? {
        await knowledgeStore.createPage(
            title: title,
            pageType: pageType,
            customIcon: customIcon,
            content: content,
            tags: tags,
            sourceURL: sourceURL,
            rawSnippet: rawSnippet,
            fileSize: fileSize,
            sourceType: sourceType
        )
    }

    /// 更新Page
    public func updatePage(_ page: KnowledgePage) async throws {
        await knowledgeStore.updatePage(page)
    }

    /// any更新Page
    public func anyUpdatePage(_ page: KnowledgePage, forceDeepScan: Bool) async {
        await knowledgeStore.updatePage(page)
    }

    /// any删除Page
    public func anyDeletePage(_ page: KnowledgePage) async {
        await knowledgeStore.deletePage(page)
    }

    /// 同步RemotePage
    public func syncRemotePage(_ page: KnowledgePage) async {
        await pageStore.syncRemotePage(page)
        await knowledgeStore.refresh()
    }

    /// 拉取BacklinksByID
    public func fetchBacklinksByID(for id: UUID) async -> [KnowledgePage] {
        await pageStore.fetchBacklinksByID(for: id)
    }

    /// 搜索Pages
    public func searchPages(query: String) async -> [KnowledgePage] {
        await pageStore.searchPages(query: query)
    }

    /// seedDefaultContent
    public func seedDefaultContent(logger: @escaping @Sendable (LogAction, String, String) -> Void) async {
        await knowledgeStore.seedDefaultContent()
    }

    /// 获取StorageStats
    public func getStorageStats() async -> StorageStats {
        await pageStore.getStorageStats()
    }
}

// MARK: - GraphDataProvider 协议实现

@MainActor
extension AppStore: GraphDataProvider {
    public var clusters: [GraphClusteringService.Cluster] { [] }
    public var isAIProcessing: Bool { isScanningAI }
}

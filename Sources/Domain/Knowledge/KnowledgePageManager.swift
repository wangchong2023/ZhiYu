//
//  KnowledgePageManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：处理知识页面的核心 CRUD、插件处理器挂载及生命周期副作用 (事件总线、打快照)，隔离底层持久化细节。
//
import Foundation
import UFPCore
import Observation
import Combine

/// 知识页面管理服务 (L1.5-Domain)
/// 负责页面生命周期管理及跨服务逻辑协同。

/// 日志模块名与操作详情前缀常量
private enum KnowledgeLogSpec {
    /// 日志模块名
    static let module = "Knowledge"
    /// 重命名操作详情前缀
    static let renamedFromPrefix = "Renamed from"
    /// 应用潜在链接详情前缀
    static let appliedPotentialLinkPrefix = "Applied potential"
    /// 应用潜在链接详情中段
    static let linkToConnector = " link to"
    /// 重构建议类型：重命名
    static let refactorTypeRename = "rename"
}

@MainActor
public final class KnowledgePageManager {
    
    @ObservationIgnored @Inject private var pageStore: any AnyPageStoreCapabilities
    @ObservationIgnored @Inject private var linkService: LinkService
    @ObservationIgnored @Inject private var undoService: UndoService
    @ObservationIgnored @Inject private var backupService: BackupService
    @ObservationIgnored @Inject private var ingestService: IngestService
    @ObservationIgnored @Inject private var logger: any LoggerProtocol
    @ObservationIgnored @Inject private var tagStore: TagStore
    @ObservationIgnored @Inject private var aiWorkflowStore: any AIWorkflowCapabilities
    @ObservationIgnored @Inject private var llmService: any LLMServiceProtocol
    @ObservationIgnored @Inject private var embeddingProvider: any EmbeddingProvider

    // MARK: - 动态处理器 (Phase 3)
    
    /// 注册处理器项
    private struct RegisteredProcessor {
        let processor: any KnowledgePageProcessor
        let pluginID: String?
    }

    /// 注册的页面处理器链
    private var processors: [RegisteredProcessor] = []
    
    /// 注册页面处理器
    /// - Parameters:
    ///   - processor: 处理器实现
    ///   - pluginID: 所属插件 ID (可选，用于生命周期管理)
    public func registerProcessor(_ processor: any KnowledgePageProcessor, pluginID: String? = nil) {
        if !processors.contains(where: { $0.processor.id == processor.id }) {
            processors.append(RegisteredProcessor(processor: processor, pluginID: pluginID))
            logger.debug(" [KnowledgePageManager] : \(processor.name) (Plugin: \(pluginID ?? "System"))")
        }
    }
    
    /// 注销页面处理器
    public func unregisterProcessor(id: String) {
        processors.removeAll { $0.processor.id == id }
    }

    /// 注销指定插件的所有处理器
    public func unregisterProcessors(for pluginID: String) {
        processors.removeAll { $0.pluginID == pluginID }
    }
    
    /// 应用处理器链
    private func applyProcessors(to page: KnowledgePage) async -> KnowledgePage {
        var result = page
        for item in processors {
            do {
                result = try await item.processor.process(page: result)
            } catch {
                logger.error(" [KnowledgePageManager]  \(item.processor.name) ", error: error)
            }
        }
        return result
    }

    public init() {}

    // MARK: - 核心 CRUD

    /// 根据标题查询页面
    public func pageByTitle(_ title: String, in pages: [KnowledgePage]) async -> KnowledgePage? {
        await linkService.pageByTitle(title, in: pages)
    }

    /// 执行创建页面的原子操作，将变更应用到持久层并更新快照。
    @discardableResult
    /// 创建知识页面
    public func createPage(
        title: String,
        pageType: PageType,
        customIcon: String? = nil,
        content: String = "",
        tags: [String] = [],
        sourceURL: String? = nil,
        rawSnippet: String? = nil,
        fileSize: Int64? = nil,
        sourceType: String? = nil,
        currentPages: [KnowledgePage]
    ) async throws -> KnowledgePage {
        undoService.pushSnapshot(currentPages)

        // 构造初始页面并执行处理器
        let initialPage = KnowledgePage(
            title: title,
            pageType: pageType,
            customIcon: customIcon,
            content: content,
            tags: tags,
            sourceURL: sourceURL,
            rawTextSnippet: rawSnippet,
            fileSize: fileSize,
            sourceType: sourceType
        )
        let processedPage = await applyProcessors(to: initialPage)

        let page = try await pageStore.createPage(
            title: processedPage.title,
            pageType: processedPage.pageType,
            customIcon: processedPage.customIcon,
            content: processedPage.content,
            tags: processedPage.tags,
            sourceURL: processedPage.sourceURL,
            rawSnippet: processedPage.rawTextSnippet,
            fileSize: processedPage.fileSize,
            sourceType: processedPage.sourceType
        )

        backupService.markDirty()
        
        let totalLinks = (try? await pageStore.fetchAllPages())?.reduce(0) { $0 + $1.outgoingLinks.count } ?? 0
        AppEventBus.shared.publish(.pageCreated(id: page.id, title: page.title, nodeCount: currentPages.count + 1, linkCount: totalLinks))

        return page
    }

    /// 更新页面
    public func updatePage(_ page: KnowledgePage, currentPages: [KnowledgePage]) async throws {
        undoService.pushSnapshot(currentPages)
        
        // 执行处理器增强
        let processedPage = await applyProcessors(to: page)
        
        try await pageStore.updatePage(processedPage)
        backupService.markDirty()
        
        let totalLinks = currentPages.reduce(0) { $0 + $1.outgoingLinks.count }
        AppEventBus.shared.publish(.pageUpdated(id: processedPage.id, nodeCount: currentPages.count, linkCount: totalLinks))
        
        // 增量同步 RAG 向量：编辑保存后，把新内容跑一次 Ingest Pipeline，确保 RAG 库内容实时一致
        let llm = self.llmService
        let embedding = self.embeddingProvider
        Task { [weak self] in
            do {
                _ = try await KnowledgeIngestPipeline.shared.process(
                    content: processedPage.content,
                    pageID: processedPage.id,
                    llm: llm,
                    embeddingProvider: embedding
                )
                self?.logger.info("[RAG Sync] Successfully synced increment embedding for page: \(processedPage.title)")
            } catch {
                self?.logger.error("[RAG Sync] Failed to sync increment embedding for page: \(processedPage.title), error: \(error)")
            }
        }
    }

    /// 保存页面 (含插件事件触发)
    public func savePage(_ page: KnowledgePage, currentPages: [KnowledgePage]) async throws {
        try await updatePage(page, currentPages: currentPages)
        PluginRegistry.shared.emitEvent("onPageSave", data: page.id.uuidString)
    }

    /// 删除页面
    public func deletePage(_ page: KnowledgePage, currentPages: [KnowledgePage]) async throws {
        undoService.pushSnapshot(currentPages)
        try await pageStore.deletePage(page)
        AppEventBus.shared.publish(.pageDeleted(id: page.id))
        PluginRegistry.shared.emitEvent("onPageDelete", data: page.id.uuidString)
    }

    /// 重命名页面 (处理双向链接)
    public func renamePage(_ page: KnowledgePage, to newTitle: String, currentPages: [KnowledgePage]) async throws {
        let oldTitle = page.title
        let modifiedPages = await linkService.prepareRename(page: page, to: newTitle, in: currentPages)

        try await pageStore.performBatchWrite { db in
            for p in modifiedPages { try p.save(db) }
        }
        logger.addLog(action: .update, target: newTitle, details: KnowledgeLogSpec.renamedFromPrefix + " \(oldTitle)", module: KnowledgeLogSpec.module)
        backupService.markDirty()
    }

    // MARK: - 撤销 / 重做

    /// 执行撤销：将页面状态回退到上一次的快照栈帧
    /// - Parameter currentPages: 当前内存状态快照
    /// - Returns: 回滚后的新快照集合
    public func undo(currentPages: [KnowledgePage]) async throws -> [KnowledgePage]? {
        if let prev = undoService.undo(currentPages: currentPages) {
            await pageStore.replaceAllPages(prev)
            return prev
        }
        return nil
    }

    /// 执行重做：恢复上一次被撤销的快照变更
    /// - Parameter currentPages: 当前内存状态快照
    /// - Returns: 重做后的新快照集合
    public func redo(currentPages: [KnowledgePage]) async throws -> [KnowledgePage]? {
        if let next = undoService.redo(currentPages: currentPages) {
            await pageStore.replaceAllPages(next)
            return next
        }
        return nil
    }

    // MARK: - 业务协同

    /// 应用潜在链接建议
    public func applyPotentialLink(_ suggestion: PotentialLinkSuggestion, currentPages: [KnowledgePage]) async throws {
        guard var page = currentPages.first(where: { $0.id == suggestion.sourcePageID }) else { return }
        
        let oldContent = page.content
        let newContent = oldContent.replacingOccurrences(
            of: suggestion.targetTitle,
            with: SystemConstants.MarkdownSyntax.wikiLinkOpen + suggestion.targetTitle + SystemConstants.MarkdownSyntax.wikiLinkClose,
            options: .caseInsensitive
        )

        if oldContent != newContent {
            page.content = newContent
            try await updatePage(page, currentPages: currentPages)
            logger.addLog(action: .update, target: page.title, details: KnowledgeLogSpec.appliedPotentialLinkPrefix + KnowledgeLogSpec.linkToConnector + " \(SystemConstants.MarkdownSyntax.wikiLinkOpen)\(suggestion.targetTitle)\(SystemConstants.MarkdownSyntax.wikiLinkClose)", module: KnowledgeLogSpec.module)
        }
    }

    /// 应用 AI 重构建议
    public func applyRefactorSuggestion(_ suggestion: RefactorSuggestion, currentPages: [KnowledgePage]) async throws {
        if suggestion.type == KnowledgeLogSpec.refactorTypeRename, let page = currentPages.first(where: { $0.title == suggestion.target }) {
            try await renamePage(page, to: suggestion.suggestion, currentPages: currentPages)
        }
        aiWorkflowStore.removeRefactorSuggestion(id: suggestion.id)
    }

    /// 导入文件夹
    public func ingestFolder(at url: URL, pageStore: any AnyPageStore) async {
        _ = await ingestService.ingestFolder(at: url, pageStore: pageStore)
    }

    // MARK: - 标签管理转发

    /// 修改现有全局标签的文本名称（级联更新所有引用页）
    /// - Parameters:
    ///   - oldTag: 旧标签名称
    ///   - newTag: 新标签名称
    public func renameTag(_ oldTag: String, to newTag: String) async {
        await tagStore.renameTag(old: oldTag, to: newTag)
    }

    /// 彻底抹除特定的全局标签（从所有页面和字典表中清除）
    /// - Parameter tag: 需要删除的标签名
    public func deleteTag(_ tag: String) async {
        await tagStore.deleteTag(tag)
    }

    /// 批量抹除多个全局标签
    /// - Parameter tags: 需要删除的标签名称数组
    public func bulkDeleteTags(_ tags: [String]) async {
        await tagStore.bulkDeleteTags(tags)
    }
}

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
import Dependencies

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
    /// 默认系统处理器来源标签
    static let systemPluginLabel = "System"
    /// 插件事件：页面保存
    static let eventOnPageSave = "onPageSave"
    /// 插件事件：页面删除
    static let eventOnPageDelete = "onPageDelete"
    /// 已有单行双链区间匹配正则，用于跳过已在双链内的文本
    static let existingWikiLinkPattern = #"\[\[[^\]\r\n]+\]\]"#
    static let zeroCount: Int = 0
    static let singleIncrement: Int = 1
}

@MainActor
public final class KnowledgePageManager {
    
    @ObservationIgnored @Dependency(\.pageStoreCapabilities) private var pageStore: any AnyPageStoreCapabilities
    @ObservationIgnored @Dependency(\.linkService) private var linkService: LinkService
    @ObservationIgnored @Dependency(\.undoService) private var undoService: UndoService?
    @ObservationIgnored @Dependency(\.backupService) private var backupService: BackupService
    @ObservationIgnored @Dependency(\.ingestService) private var ingestService: any IngestServiceProtocol
    @ObservationIgnored @Dependency(\.logger) private var logger: any LoggerProtocol
    @ObservationIgnored @Dependency(\.tagStore) private var tagStore: TagStore
    @ObservationIgnored @Dependency(\.aiWorkflowCapabilities) private var aiWorkflowStore: any AIWorkflowCapabilities
    @ObservationIgnored @Dependency(\.llmService) private var llmService: any LLMServiceProtocol
    @ObservationIgnored @Dependency(\.embeddingProvider) private var embeddingProvider: any EmbeddingProvider
    @ObservationIgnored @Dependency(\.pluginRegistry) private var pluginRegistry

    /// 按页面 ID 追踪进行中的增量 RAG 同步任务，连续编辑保存时先取消旧任务防止乱序覆写索引
    private var activeRAGSyncTasks: [UUID: Task<Void, Never>] = [:]

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
            logger.debug(" [KnowledgePageManager] : \(processor.name) (Plugin: \(pluginID ?? KnowledgeLogSpec.systemPluginLabel))")
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
        undoService?.pushSnapshot(currentPages)

        // 构造初始页面并执行处理器
        let initialPage = KnowledgePage(input: CreatePageInput(
            title: title, pageType: pageType, customIcon: customIcon, content: content,
            tags: tags, sourceURL: sourceURL, rawSnippet: rawSnippet,
            fileSize: fileSize, sourceType: sourceType))
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
        
        let totalLinks = (try? await pageStore.fetchAllPages())?.reduce(KnowledgeLogSpec.zeroCount) { $0 + $1.outgoingLinks.count } ?? KnowledgeLogSpec.zeroCount
        AppEventBus.shared.publish(.pageCreated(id: page.id, title: page.title, nodeCount: currentPages.count + KnowledgeLogSpec.singleIncrement, linkCount: totalLinks))

        return page
    }

    /// 更新页面
    public func updatePage(_ page: KnowledgePage, currentPages: [KnowledgePage]) async throws {
        undoService?.pushSnapshot(currentPages)
        
        // 执行处理器增强
        let processedPage = await applyProcessors(to: page)
        
        try await pageStore.updatePage(processedPage)
        backupService.markDirty()
        
        let totalLinks = currentPages.reduce(KnowledgeLogSpec.zeroCount) { $0 + $1.outgoingLinks.count }
        AppEventBus.shared.publish(.pageUpdated(id: processedPage.id, nodeCount: currentPages.count, linkCount: totalLinks))
        
        // 增量同步 RAG 向量：编辑保存后，先取消同页旧同步任务，再跑新内容的 Ingest Pipeline，防止乱序覆写
        let llm = self.llmService
        let embedding = self.embeddingProvider
        let pageID = processedPage.id
        activeRAGSyncTasks[pageID]?.cancel()
        activeRAGSyncTasks[pageID] = Task { [weak self] in
            defer {
                if self?.activeRAGSyncTasks[pageID]?.isCancelled == false {
                    self?.activeRAGSyncTasks.removeValue(forKey: pageID)
                }
            }
            do {
                _ = try await KnowledgeIngestPipeline.shared.process(
                    content: processedPage.content,
                    pageID: pageID,
                    llm: llm,
                    embeddingProvider: embedding
                )
                self?.logger.info("[RAG Sync] Successfully synced increment embedding for page: \(processedPage.title)")
            } catch is CancellationError {
                return
            } catch {
                self?.logger.error("[RAG Sync] Failed to sync increment embedding for page: \(processedPage.title), error: \(error)")
            }
        }
    }

    /// 保存页面 (含插件事件触发)
    public func savePage(_ page: KnowledgePage, currentPages: [KnowledgePage]) async throws {
        try await updatePage(page, currentPages: currentPages)
        pluginRegistry.emitEvent(KnowledgeLogSpec.eventOnPageSave, data: page.id.uuidString)
    }

    /// 删除页面
    public func deletePage(_ page: KnowledgePage, currentPages: [KnowledgePage]) async throws {
        activeRAGSyncTasks.removeValue(forKey: page.id)?.cancel()
        undoService?.pushSnapshot(currentPages)
        try await pageStore.deletePage(page)
        // 缺陷 #84 修复：删除也是数据变更，与 create/update/rename 一致标记备份脏位，
        // 否则备份/崩溃恢复系统不感知删除这一变更
        backupService.markDirty()
        AppEventBus.shared.publish(.pageDeleted(id: page.id))
        pluginRegistry.emitEvent(KnowledgeLogSpec.eventOnPageDelete, data: page.id.uuidString)
    }

    /// 重命名页面 (处理双向链接)
    public func renamePage(_ page: KnowledgePage, to newTitle: String, currentPages: [KnowledgePage]) async throws {
        let oldTitle = page.title
        let modifiedPages = await linkService.prepareRename(page: page, to: newTitle, in: currentPages)
        guard !modifiedPages.isEmpty else { return }

        undoService?.pushSnapshot(currentPages)
        try await pageStore.performBatchWrite { db in
            for p in modifiedPages { try p.save(db) }
        }
        let resolvedNewTitle = modifiedPages.first?.title ?? newTitle
        logger.addLog(action: .update, target: resolvedNewTitle, details: KnowledgeLogSpec.renamedFromPrefix + " \(oldTitle)", module: KnowledgeLogSpec.module)
        backupService.markDirty()
    }

    // MARK: - 撤销 / 重做

    /// 执行撤销：将页面状态回退到上一次的快照栈帧
    /// - Parameter currentPages: 当前内存状态快照
    /// - Returns: 回滚后的新快照集合
    public func undo(currentPages: [KnowledgePage]) async throws -> [KnowledgePage]? {
        if let prev = undoService?.undo(currentPages: currentPages) {
            await pageStore.replaceAllPages(prev)
            return prev
        }
        return nil
    }

    /// 执行重做：恢复上一次被撤销的快照变更
    /// - Parameter currentPages: 当前内存状态快照
    /// - Returns: 重做后的新快照集合
    public func redo(currentPages: [KnowledgePage]) async throws -> [KnowledgePage]? {
        if let next = undoService?.redo(currentPages: currentPages) {
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
        let newContent = Self.wrapPlainOccurrences(
            in: oldContent,
            target: suggestion.targetTitle,
            open: SystemConstants.MarkdownSyntax.wikiLinkOpen,
            close: SystemConstants.MarkdownSyntax.wikiLinkClose
        )

        if oldContent != newContent {
            page.content = newContent
            try await updatePage(page, currentPages: currentPages)
            logger.addLog(action: .update, target: page.title, details: KnowledgeLogSpec.appliedPotentialLinkPrefix + KnowledgeLogSpec.linkToConnector + " \(SystemConstants.MarkdownSyntax.wikiLinkOpen)\(suggestion.targetTitle)\(SystemConstants.MarkdownSyntax.wikiLinkClose)", module: KnowledgeLogSpec.module)
        }
    }

    /// 将文本中未被双链包裹的目标标题出现位置包裹为双链，跳过已处于 `[[...]]`（含别名/锚点）内的匹配，
    /// 并使用 `Range(nsRange, in:)` 避免含 Emoji/多字节 UTF-16 字符时的索引越界崩溃。
    /// - Parameters:
    ///   - content: 原始正文
    ///   - target: 待链接化的标题（大小写不敏感）
    ///   - open: 双链左括号
    ///   - close: 双链右括号
    /// - Returns: 处理后的正文；若无合法匹配则原样返回
    internal static func wrapPlainOccurrences(
        in content: String,
        target: String,
        open: String,
        close: String
    ) -> String {
        let trimmedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty else { return content }

        let escaped = NSRegularExpression.escapedPattern(for: trimmedTarget)
        guard let targetRegex = try? NSRegularExpression(pattern: escaped, options: [.caseInsensitive]) else {
            return content
        }

        let nsContent = content as NSString
        let fullRange = NSRange(location: KnowledgeLogSpec.zeroCount, length: nsContent.length)
        let matches = targetRegex.matches(in: content, range: fullRange)
        guard !matches.isEmpty else { return content }

        // 先收集正文中所有已有 [[...]] 区间，禁止在已有双链（如 [[Target|别名]] 或 [[Other|Target]]）内部重复嵌套
        let existingLinkRanges: [NSRange]
        if let linkRegex = try? NSRegularExpression(pattern: KnowledgeLogSpec.existingWikiLinkPattern) {
            existingLinkRanges = linkRegex.matches(in: content, range: fullRange).map(\.range)
        } else {
            existingLinkRanges = []
        }

        var result = content
        // 从后向前使用安全的 UTF-16 -> Swift Range 转换替换，彻底规避 Emoji 越界闪退
        for match in matches.reversed() {
            let overlapsExistingLink = existingLinkRanges.contains {
                NSIntersectionRange(match.range, $0).length > KnowledgeLogSpec.zeroCount
            }
            guard !overlapsExistingLink, let swiftRange = Range(match.range, in: result) else { continue }
            let plain = String(result[swiftRange])
            result.replaceSubrange(swiftRange, with: open + plain + close)
        }
        return result
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
        _ = await ingestService.ingestFolder(at: url, type: .source, pageStore: pageStore)
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

// MARK: - DependencyKey

extension KnowledgePageManager: DependencyKey {
    nonisolated public static var liveValue: KnowledgePageManager {
        ServiceContainer.shared.resolveOptional(KnowledgePageManager.self)
            ?? runOnMainSync { KnowledgePageManager() }
    }
    nonisolated public static var testValue: KnowledgePageManager {
        ServiceContainer.shared.resolveOptional(KnowledgePageManager.self)
            ?? runOnMainSync { KnowledgePageManager() }
    }
}

extension DependencyValues {
    /// 知识页管理器依赖
    public var pageManager: KnowledgePageManager {
        get { self[KnowledgePageManager.self] }
        set { self[KnowledgePageManager.self] = newValue }
    }
}

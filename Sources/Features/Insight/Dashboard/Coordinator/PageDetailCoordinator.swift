//
//  PageDetailCoordinator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：负责 PageDetail 业务流的导航路由与协作管理。
//
import SwiftUI
import UFPCore
import Observation
import Dependencies

@MainActor
@Observable
final class PageDetailCoordinator {
    @ObservationIgnored @Dependency(\.toastService) private var toastManager
    var page: KnowledgePage
    var isEditing = false
    var showBacklinks = false
    var showDeleteConfirmation = false
    var showAliasEditor = false
    var newAlias = ""
    var showIconPicker = false
    var showSnapshotHistory = false
    var hasScannedForLinks = false
    
    // AI 任务相关状态由注入的 aiStore 提供

    @ObservationIgnored @Inject private var store: AppStore
    @ObservationIgnored @Inject private var aiStore: AIWorkflowStore

    init(page: KnowledgePage) {
        self.page = page
    }

    var backlinks: [KnowledgePage] {
        store.pages.filter { page in
            WikiLinkExtractor.extractLinks(from: page.content).contains { $0.targetTitle == self.page.title }
        }
    }

    // ── 核心业务 ──

    /// 删除Page
    func deletePage() async {
        await store.deletePage(page)
    }

    /// 切换置顶
    func togglePin() async {
        var updated = page
        updated.isPinned.toggle()
        await store.savePage(updated)
        page = updated
    }

    // ── AI 任务编排 ──

    /// 通用 AI 任务执行模板，统一处理 Toast/Haptic/错误提示
    /// - Parameter operation: 异步 AI 操作
    private func runAIOperation(_ operation: @escaping () async throws -> Void) {
        Task {
            toastManager.show(type: .processing, message: L10n.Common.aiThinking, duration: 0)
            do {
                try await operation()
                HapticFeedback.shared.trigger(.success)
                toastManager.dismiss()
            } catch {
                toastManager.show(type: .error, message: error.localizedDescription)
            }
        }
    }

    /// 生成Summary
    /// - Note: 返回值由 `aiStore` 内部状态持有，coordinator 无需保存
    func generateSummary() {
        runAIOperation { _ = try await self.aiStore.runPageAISummary(content: self.page.content) }
    }

    /// 提取Actions
    /// - Note: 返回值由 `aiStore` 内部状态持有，coordinator 无需保存
    func extractActions() {
        runAIOperation { _ = try await self.aiStore.runPageAIExtractActions(content: self.page.content) }
    }

    /// expandContent
    /// - Note: 返回值由 `aiStore` 内部状态持有，coordinator 无需保存
    func expandContent() {
        runAIOperation { _ = try await self.aiStore.runPageAIExpansion(content: self.page.content) }
    }

    /// 执行Synthesis
    /// - Parameter type: type
    /// - Note: 返回值由 `aiStore` 内部状态持有，coordinator 无需保存
    func performSynthesis(type: SynthesisStore.SynthesisType) {
        runAIOperation { _ = try await self.aiStore.performPageSynthesis(type: type, title: self.page.title, content: self.page.content) }
    }
    
    /// 查找RelatedLinks
    func findRelatedLinks() {
        hasScannedForLinks = true
        Task {
            await aiStore.runAIScan(forPage: page)
        }
    }
}

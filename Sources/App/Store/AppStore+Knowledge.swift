//
//  AppStore+Knowledge.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：AppStore 的知识库业务扩展 — 页面操作、笔记本种子数据生成与链接建议应用。
//
import SwiftUI

// MARK: - 知识库业务扩展

extension AppStore {

    /// 应用Potential链接
    public func applyPotentialLink(_ suggestion: PotentialLinkSuggestion) async {
        await knowledgeStore.applyPotentialLink(suggestion)
    }

    /// 应用重构Suggestion
    func applyRefactorSuggestion(_ suggestion: RefactorSuggestion) async {
        await knowledgeStore.applyRefactorSuggestion(suggestion)
    }
}

// MARK: - 笔记本种子生成

extension AppStore: CollaborationDelegate {
    @discardableResult

    /// 生成初始笔记本
    func generateInitialNotebooks() async -> (total: Int, details: [(name: String, count: Int)]) {
        guard let service = maintenanceService else { return (0, []) }
        let result = await service.generateInitialNotebooks()
        if result.total > 0 {
            await refresh()
            AppEventBus.shared.publish(.graphRelayoutRequested)
        }
        return result
    }

    /// 应用Remote更新
    public func applyRemoteUpdate(_ page: KnowledgePage) async {
        await knowledgeStore.updatePage(page)
    }

    /// 插入RemotePage
    public func insertRemotePage(_ page: KnowledgePage) async {
        await pageStore.syncRemotePage(page)
        await refresh()
    }

    /// 清除AllDeveloperData
    func clearAllDeveloperData() {
        Task {
            AppEventBus.shared.publish(.clearAllDataRequested)
            await maintenanceService?.clearAllDeveloperData()
            await refresh()
        }
    }
}

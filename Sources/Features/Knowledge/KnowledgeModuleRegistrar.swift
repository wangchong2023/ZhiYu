//
//  KnowledgeModuleRegistrar.swift
//  ZhiYu
//
//  系统层级：[L2] 领域层 — 知识管理服务注册
//  核心职责：注册知识页面、采集、检查、洞察等 Knowledge 领域服务
//  依赖：StorageModuleRegistrar (L1) ＋ AuthModuleRegistrar 已完成
//

import Foundation

// MARK: - 知识管理模块 (L2)

/// 知识模块注册器：负责 Knowledge 领域核心服务
@MainActor
struct KnowledgeModuleRegistrar: ModuleRegistrar {

    /// 注册知识管理领域的逻辑与处理器
    static func register(in container: ServiceContainer) {
        Logger.shared.info("[DI] Starting registration of knowledge modules...")

        container.register(LinkService(), for: LinkService.self)
        container.register(IngestService(), for: IngestService.self)
        container.register(LintService(), for: LintService.self)
        container.register(UndoService(), for: UndoService.self)
        container.register(KnowledgeInsightService(), for: KnowledgeInsightService.self)
        container.register(KnowledgePageManager(), for: KnowledgePageManager.self)
        // KnowledgeStore 由 AppStore 统一创建并注册，此处不再重复
        container.register(MaintenanceService(), for: MaintenanceService.self)

        container.register(ChatService.shared as any ChatServiceProtocol, for: (any ChatServiceProtocol).self)
        container.register(ChatService.shared, for: ChatService.self)

        Logger.shared.info("[DI] Knowledge module registration completed")
    }
}

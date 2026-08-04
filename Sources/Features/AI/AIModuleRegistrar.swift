//
//  AIModuleRegistrar.swift
//  ZhiYu
//
//  系统层级：[L2] 领域层 — AI 能力服务注册
//  核心职责：注册 LLM、RAG、合成、Prompt 等 AI 领域服务
//  依赖：StorageModuleRegistrar (L1) ＋ KnowledgeModuleRegistrar 已完成
//

import Foundation
import UFPCore

// MARK: - AI 能力模块 (L2)

/// AI 模块注册器：负责 LLM、RAG 编排、合成、Prompt 等 AI 核心服务 (@PR-02)
@MainActor
struct AIModuleRegistrar: ModuleRegistrar {

    /// 注册 AI 能力领域的全部服务
    static func register(in container: ServiceContainer) {
        Logger.shared.info("[DI] Starting registration of AI capability modules...")

        // 平台特定 OCR / 语音服务（watchOS 由 WatchPlatformRegistrar 注册）
        container.register(iOSOCRService(), for: (any OCRServiceProtocol).self)
        container.register(iOSSpeechService(), for: (any SpeechServiceProtocol).self)

        // AI 基础设施
        container.register(LLMConfigManager(), for: LLMConfigManager.self)
        container.register(AIAnalyticsService(), for: AIAnalyticsService.self)
        container.register(RAGOrchestrator(), for: RAGOrchestrator.self)

        // 远程配置服务
        container.register(RemoteConfigService() as any RemoteConfigCapabilities, for: (any RemoteConfigCapabilities).self)
        
        // 注册大模型权重文件后台下载管理器与契约能力
        let downloadManager = ModelDownloadManager.shared
        container.register(downloadManager as any ModelDownloadCapabilities, for: (any ModelDownloadCapabilities).self)
        container.register(downloadManager, for: ModelDownloadManager.self)

        // LLM 协议实现
        container.register(ChatRunner(), for: (any LLMChatServiceProtocol).self)
        container.register(IngestProcessor(), for: (any LLMKnowledgeServiceProtocol).self)
        container.register(QueryReranker(), for: (any LLMRetrievalServiceProtocol).self)

        let llm = LLMService.shared
        container.register(llm as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        container.register(llm, for: LLMService.self)
        container.register(AISynthesisService.shared as any AISynthesisServiceProtocol, for: (any AISynthesisServiceProtocol).self)
        container.register(AISynthesisService.shared, for: AISynthesisService.self)
        container.register(PromptService.shared, for: PromptService.self)

        // RAG 评估服务 — 依赖 RAGGovernanceRepository (L1 已注册)
        Logger.shared.info("[DI] Initializing RAGEvaluationService...")
        if container.hasService(for: (any RAGGovernanceRepository).self) {
            let evaluationService = RAGEvaluationService(
                llmService: llm,
                governanceStore: container.resolve((any RAGGovernanceRepository).self)
            )
            container.register(evaluationService, for: RAGEvaluationService.self)
        } else {
            Logger.shared.error("[DI] RAGGovernanceRepository not registered! RAGEvaluationService initialization will fail.")
        }

        Logger.shared.info("[DI] AI capability module registration completed")
    }
}

//
//  ChatLLMService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 ChatLLM 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
import Combine
import Dependencies

/// 大模型对话与文本生成基础设施服务
/// 遵循并实现 `LLMChatServiceProtocol` 契约，支持响应式状态变化。
@MainActor
public final class ChatLLMService: NSObject, LLMChatServiceProtocol {
    /// 配置管理器，热重载 API 参数
    @ObservationIgnored @Dependency(\.llmConfigManager) private var configManager: LLMConfigManager
    
    /// AI 吞吐指标记录器
    @ObservationIgnored @Dependency(\.aiAnalyticsService) private var analytics: AIAnalyticsService

    /// LLMContextBuilder 工厂闭包 — 生产环境创建默认实例，测试环境可注入 mock
    @ObservationIgnored private let contextBuilderFactory: @Sendable () -> LLMContextBuilder

    /// 指示当前大模型服务是否使能开启
    public var isEnabled: Bool {
        configManager.isEnabled
    }

    /// 生产环境初始化器
    public override init() {
        self.contextBuilderFactory = { LLMContextBuilder() }
        super.init()
    }

    /// 测试环境初始化器 — 允许注入自定义 LLMContextBuilder 工厂
    /// - Parameter contextBuilderFactory: 返回自定义 LLMContextBuilder 的工厂闭包
    init(contextBuilderFactory: @escaping @Sendable () -> LLMContextBuilder) {
        self.contextBuilderFactory = contextBuilderFactory
        super.init()
    }
    
    /// 执行一问一答生成推理
    ///
    /// - Parameters:
    ///   - prompt: 提示词
    ///   - systemPrompt: 系统设定
    /// - Returns: 生成纯文本结果
    public func generate(prompt: String, systemPrompt: String, maxTokens: Int = PromptConstants.TokenLimits.defaultMaxOutputTokens) async throws -> String {
        // UI 自动化测试靶场下的智能自愈：直接返回本地 Mock 保证 100% 绿通
        if LLMMockResponder.isUITesting {
            return try await LLMMockResponder.mockNonStreamReply()
        }

        guard isEnabled, !configManager.apiKey.isEmpty else {
            throw LLMError.notConfigured
        }
        let client = LLMClient(baseURL: configManager.baseURL, apiKey: configManager.apiKey)
        let sanitizedPrompt = PromptSanitizer.shared.sanitize(prompt)
        let body = LLMRequestBuilder.systemUserBody(
            model: configManager.model,
            systemPrompt: systemPrompt,
            userPrompt: sanitizedPrompt,
            temperature: AppConfig.AI.defaultTemperature,
            maxTokens: maxTokens
        )

        return try await LLMResponseHandler.sendRecordAndExtract(
            client: client,
            body: body,
            model: configManager.model,
            analytics: analytics
        )
    }
    
    /// 执行核心会话对话
    ///
    /// - Parameters:
    ///   - query: 查询问句
    ///   - history: 历史纪录
    ///   - pages: 关联的知识背景页面
    /// - Returns: 会话响应数据
    public func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        // UI 自动化测试靶场下的智能自愈：直接返回本地 RAG Mock 保证 100% 绿通
        if LLMMockResponder.isUITesting {
            return try await LLMMockResponder.mockRAGReply(pages: pages)
        }

        guard isEnabled, !configManager.apiKey.isEmpty else {
            throw LLMError.notConfigured
        }
        let client = LLMClient(baseURL: configManager.baseURL, apiKey: configManager.apiKey)
        let chatService = LLMChatService(client: client, model: configManager.model)

        // 1. 对 query 进行消毒过滤并构建脱敏上下文
        let sanitizedQuery = PromptSanitizer.shared.sanitize(query)
        let contextBuilder = contextBuilderFactory()
        let anonResult = buildAnonymizedContext(
            sanitizedQuery: sanitizedQuery,
            history: history,
            pages: pages,
            contextBuilder: contextBuilder
        )

        // 2. 调用底层的 chatService 执行物理会话
        let response = try await chatService.chat(systemPrompt: anonResult.anonSystemPrompt, query: anonResult.anonQuery, history: anonResult.anonHistory)

        // 🔓 端侧还原 (SR-12)
        let deanonymizedResponse = contextBuilder.deanonymize(response, mapping: anonResult.currentMapping)

        return ChatMessageDTO(
            id: UUID(),
            role: .assistant,
            content: deanonymizedResponse,
            timestamp: Date(),
            relatedPageIDs: pages.map { $0.id }
        )
    }
    
    /// 执行流式会话对话，支持打字机吐字渲染
    ///
    /// - Parameters:
    ///   - query: 查询问句
    ///   - history: 历史纪录
    ///   - pages: 关联的知识背景页面
    /// - Returns: 流式字符串抛出流
    public func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        // UI 自动化测试靶场下的智能自愈：模拟流式打字机延迟吐字，验证骨架屏 (Skeleton) 与流中止 (Stop-flow) 机制
        if LLMMockResponder.isUITesting {
            return LLMMockResponder.mockStream()
        }

        guard isEnabled, !configManager.apiKey.isEmpty else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: LLMError.notConfigured)
            }
        }

        let client = LLMClient(baseURL: configManager.baseURL, apiKey: configManager.apiKey)
        let chatService = LLMChatService(client: client, model: configManager.model)
        let sanitizedQuery = PromptSanitizer.shared.sanitize(query)

        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()

        // 1. 使用后台异步任务生成上下文与启动流式返回
        Task {
            do {
                let contextBuilder = contextBuilderFactory()
                let anonResult = buildAnonymizedContext(
                    sanitizedQuery: sanitizedQuery,
                    history: history,
                    pages: pages,
                    contextBuilder: contextBuilder
                )

                let sseStream = chatService.streamChat(systemPrompt: anonResult.anonSystemPrompt, query: anonResult.anonQuery, history: anonResult.anonHistory)
                for try await chunk in sseStream {
                    // 🔓 端侧还原 (SR-12)：流式逐 chunk 还原占位符
                    let deanonymizedChunk = contextBuilder.deanonymize(chunk, mapping: anonResult.currentMapping)
                    continuation.yield(deanonymizedChunk)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }

        return stream
    }

    // MARK: - 辅助方法

    /// 构建脱敏后的会话上下文（系统提示词 + 查询 + 历史）
    /// - Parameters:
    ///   - sanitizedQuery: 已消毒的查询字符串
    ///   - history: 历史会话消息
    ///   - pages: 关联的知识背景页面
    ///   - contextBuilder: 上下文构建器
    /// - Returns: 脱敏后的上下文结果
    private func buildAnonymizedContext(
        sanitizedQuery: String,
        history: [ChatMessageDTO],
        pages: [any KnowledgePageRepresentable],
        contextBuilder: LLMContextBuilder
    ) async -> LLMAnonymizationHelper.AnonymizationResult {
        let (context, _) = await contextBuilder.buildRelevantContext(query: sanitizedQuery)
        let sandboxedContext = PromptSanitizer.shared.wrapInSandbox(context)
        let systemPrompt = contextBuilder.buildSystemPrompt(pages: pages) + "\n\n" + sandboxedContext

        // 🔒 端侧 NER 脱敏 (SR-12)：防止敏感信息发送给云端 LLM
        return LLMAnonymizationHelper.anonymize(
            systemPrompt: systemPrompt,
            query: sanitizedQuery,
            history: history,
            contextBuilder: contextBuilder
        )
    }
}

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
    
    /// 指示当前大模型服务是否使能开启
    public var isEnabled: Bool {
        configManager.isEnabled
    }
    
    /// 初始化对话服务
    public override init() {
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
        if ProcessInfo.processInfo.arguments.contains(LLMConstants.UITesting.launchArg) {
            try? await Task.sleep(nanoseconds: UInt64(LLMConstants.UITesting.mockNonStreamDelaySeconds * LLMConstants.UITesting.nanosecondsPerSecond))
            return LLMConstants.UITesting.mockNonStreamReply
        }
        
        guard isEnabled, !configManager.apiKey.isEmpty else {
            throw LLMError.notConfigured
        }
        let client = LLMClient(baseURL: configManager.baseURL, apiKey: configManager.apiKey)
        let sanitizedPrompt = PromptSanitizer.shared.sanitize(prompt)
        let body: [String: Any] = [
            LLMConstants.APIKey.model: configManager.model,
            LLMConstants.APIKey.messages: [
                [LLMConstants.APIKey.role: LLMConstants.Role.system, LLMConstants.APIKey.content: systemPrompt],
                [LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: sanitizedPrompt]
            ],
            LLMConstants.APIKey.temperature: AppConfig.AI.defaultTemperature,
            LLMConstants.APIKey.maxTokens: maxTokens
        ]
        
        let startTime = Date()
        let response = try await client.sendRequest(body: body)
        let latency = Int(Date().timeIntervalSince(startTime) * Double(UFPCore.SystemConstants.millisecondsPerSecond))
        
        analytics.recordUsage(model: configManager.model, response: response, latency: latency)
        
        guard let content = LLMUtils.extractContent(from: response) else {
            throw LLMError.invalidResponse
        }
        return content
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
        if ProcessInfo.processInfo.arguments.contains(LLMConstants.UITesting.launchArg) {
            try? await Task.sleep(nanoseconds: UInt64(LLMConstants.UITesting.mockNonStreamDelaySeconds * LLMConstants.UITesting.nanosecondsPerSecond))
            return ChatMessageDTO(
                id: UUID(),
                role: .assistant,
                content: LLMConstants.UITesting.mockRAGReply,
                timestamp: Date(),
                relatedPageIDs: pages.map { $0.id }
            )
        }
        
        guard isEnabled, !configManager.apiKey.isEmpty else {
            throw LLMError.notConfigured
        }
        let client = LLMClient(baseURL: configManager.baseURL, apiKey: configManager.apiKey)
        let chatService = LLMChatService(client: client, model: configManager.model)
        
        // 1. 对 query 进行消毒过滤
        let sanitizedQuery = PromptSanitizer.shared.sanitize(query)
        
        // 2. 组装系统提示词与相关页面上下文
        let contextBuilder = LLMContextBuilder()
        let (context, _) = await contextBuilder.buildRelevantContext(query: sanitizedQuery)
        let sandboxedContext = PromptSanitizer.shared.wrapInSandbox(context)
        let systemPrompt = contextBuilder.buildSystemPrompt(pages: pages) + "\n\n" + sandboxedContext
        
        // 🔒 端侧 NER 脱敏 (SR-12)：对齐 ChatRunner.chat，防止敏感信息发送给云端 LLM
        let (anonSystemPrompt, mapping1) = contextBuilder.anonymize(systemPrompt)
        let (anonQuery, mapping2) = contextBuilder.anonymize(sanitizedQuery, existingMapping: mapping1)
        
        var anonHistory: [ChatMessageDTO] = []
        var currentMapping = mapping2
        for msg in history {
            let (anonContent, nextMapping) = contextBuilder.anonymize(msg.content, existingMapping: currentMapping)
            currentMapping = nextMapping
            anonHistory.append(ChatMessageDTO(role: msg.role, content: anonContent))
        }
        
        // 3. 调用底层的 chatService 执行物理会话
        let response = try await chatService.chat(systemPrompt: anonSystemPrompt, query: anonQuery, history: anonHistory)
        
        // 🔓 端侧还原 (SR-12)
        let deanonymizedResponse = contextBuilder.deanonymize(response, mapping: currentMapping)
        
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
        if ProcessInfo.processInfo.arguments.contains(LLMConstants.UITesting.launchArg) {
            return AsyncThrowingStream { continuation in
                Task {
                    // 模拟在发送大语言模型请求之前的 RAG 检索/思考状态，以留出时间给 UI 测试捕获骨架屏
                    try? await Task.sleep(nanoseconds: UInt64(LLMConstants.UITesting.mockStreamInitialDelaySeconds * LLMConstants.UITesting.nanosecondsPerSecond))

                    let mockChunks = LLMConstants.UITesting.mockStreamChunks
                    for chunk in mockChunks {
                        if Task.isCancelled {
                            break
                        }
                        continuation.yield(chunk)
                        // 模拟字间吐字延迟
                        try? await Task.sleep(nanoseconds: UInt64(LLMConstants.UITesting.mockStreamChunkDelaySeconds * LLMConstants.UITesting.nanosecondsPerSecond))
                    }
                    continuation.finish()
                }
            }
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
                let contextBuilder = LLMContextBuilder()
                let (context, _) = await contextBuilder.buildRelevantContext(query: sanitizedQuery)
                let sandboxedContext = PromptSanitizer.shared.wrapInSandbox(context)
                let systemPrompt = contextBuilder.buildSystemPrompt(pages: pages) + "\n\n" + sandboxedContext

                // 🔒 端侧 NER 脱敏 (SR-12)：对齐 chat 方法，防止敏感信息发送给云端 LLM
                let (anonSystemPrompt, mapping1) = contextBuilder.anonymize(systemPrompt)
                let (anonQuery, mapping2) = contextBuilder.anonymize(sanitizedQuery, existingMapping: mapping1)

                var anonHistory: [ChatMessageDTO] = []
                var currentMapping = mapping2
                for msg in history {
                    let (anonContent, nextMapping) = contextBuilder.anonymize(msg.content, existingMapping: currentMapping)
                    currentMapping = nextMapping
                    anonHistory.append(ChatMessageDTO(role: msg.role, content: anonContent))
                }

                let sseStream = chatService.streamChat(systemPrompt: anonSystemPrompt, query: anonQuery, history: anonHistory)
                for try await chunk in sseStream {
                    // 🔓 端侧还原 (SR-12)：流式逐 chunk 还原占位符
                    let deanonymizedChunk = contextBuilder.deanonymize(chunk, mapping: currentMapping)
                    continuation.yield(deanonymizedChunk)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }

        return stream
    }
}

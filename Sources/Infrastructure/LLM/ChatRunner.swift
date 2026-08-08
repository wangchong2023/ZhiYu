//
//  ChatRunner.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：提供专属的大语言模型单轮/多轮对话与流式文本推理业务能力。
//

import Foundation
import UFPCore
import Combine

/// 大语言模型对话专属运行器 (ChatRunner)
/// 实现 LLMChatServiceProtocol，负责多轮对话、流式推理以及通用内容生成。
@MainActor
final class ChatRunner: LLMChatServiceProtocol, @unchecked Sendable {
    
    // MARK: - 依赖注入
    
    @ObservationIgnored @Inject private var configManager: LLMConfigManager
    @ObservationIgnored @Inject private var analytics: AIAnalyticsService
    @ObservationIgnored @Inject private var logger: any LoggerProtocol
    @ObservationIgnored @Inject private var reranker: any LLMRetrievalServiceProtocol

    // MARK: - 内部属性
    
    /// 上下文构建器
    private let contextBuilder = LLMContextBuilder()
    
    /// 核心对话子服务
    private var chatService: LLMChatService?
    
    var isEnabled: Bool {
        configManager.isEnabled
    }
    
    // MARK: - 初始化
    
    init() {
        updateSubServices()
        
        // 绑定配置中心刷新事件
        configManager.setRefreshHandler { [weak self] in
            self?.updateSubServices()
        }
    }
    
    private func updateSubServices() {
        let client = LLMClient(baseURL: configManager.baseURL, apiKey: configManager.apiKey)
        self.chatService = LLMChatService(client: client, model: configManager.model, logger: logger)
    }
    
    // MARK: - LLMChatServiceProtocol 契约方法
    
    /// 通用单次一问一答文本推理生成接口
    func generate(prompt: String, systemPrompt: String, maxTokens: Int = PromptConstants.TokenLimits.defaultMaxOutputTokens) async throws -> String {
        // UI 自动化测试模式下的自愈：在测试环境下拦截并返回本地 Mock 生成数据以保证 100% 绿通，规避真实 API 可达性限制
        if ProcessInfo.processInfo.arguments.contains(LLMConstants.UITesting.launchArg) {
            try? await Task.sleep(nanoseconds: UInt64(LLMConstants.UITesting.mockNonStreamDelaySeconds * LLMConstants.UITesting.nanosecondsPerSecond))
            return LLMConstants.UITesting.mockNonStreamReply
        }
        
        guard configManager.isEnabled, !configManager.apiKey.isEmpty else { throw LLMError.notConfigured }
        let client = LLMClient(baseURL: configManager.baseURL, apiKey: configManager.apiKey)
        let sanitizedPrompt = PromptSanitizer.shared.sanitize(prompt)
        
        // 🔒 端侧 NER 脱敏 (SR-12)
        let (anonSystemPrompt, mapping1) = contextBuilder.anonymize(systemPrompt)
        let (anonPrompt, mapping) = contextBuilder.anonymize(sanitizedPrompt, existingMapping: mapping1)
        
        let body: [String: Any] = [
            LLMConstants.APIKey.model: configManager.model,
            LLMConstants.APIKey.messages: [
                [LLMConstants.APIKey.role: LLMConstants.Role.system, LLMConstants.APIKey.content: anonSystemPrompt],
                [LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: anonPrompt]
            ],
            LLMConstants.APIKey.temperature: AppConfig.AI.defaultTemperature,
            LLMConstants.APIKey.maxTokens: maxTokens
        ]
 
        let startTime = Date()
        let response = try await client.sendRequest(body: body)
        let latency = Int(Date().timeIntervalSince(startTime) * Double(UFPCore.SystemConstants.millisecondsPerSecond))

        // 审计调用时长与 Token 开销
        analytics.recordUsage(model: configManager.model, response: response, latency: latency)
 
        guard let content = LLMUtils.extractContent(from: response) else {
            throw LLMError.invalidResponse
        }
        
        // 🔓 端侧还原 (SR-12)
        return contextBuilder.deanonymize(content, mapping: mapping)
    }
    
    /// 执行核心 RAG (检索增强生成) 问答
    func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        // UI 自动化测试模式下的自愈：拦截真实 RAG 调用并返回本地 Mock 数据以保证 100% 绿通，规避真实 API 密钥缺失与网关问题
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
        
        guard configManager.isEnabled, let chatService = self.chatService else { throw LLMError.notConfigured }
        let sanitizedQuery = PromptSanitizer.shared.sanitize(query)
 
        // 1. 在 UI 层启动任务中心异步进度条
        let taskID = TaskCenter.shared.addTask(type: .ai, name: LLMConstants.TaskName.aiChat, target: sanitizedQuery)
        TaskCenter.shared.updateTask(taskID, status: .running(progress: 0.2, stage: .embedding))
        
        // 2. 检索向量库及 FTS5 混合语义，构建保护双链的语义上下文
        let (context, sources) = await contextBuilder.buildRelevantContext(query: sanitizedQuery)
        SourceStore.shared.updateSources(sources)
        let capturedSources = sources  // 捕获用于异步评估
        
        // 3. 执行语义重排，精简检索召回的冗余分块
        TaskCenter.shared.updateTask(taskID, status: .running(progress: 0.5, stage: .retrieval))
        
        // 获取 Reranker 服务以进行语义重排
        let rankedPages = (try? await reranker.rerank(query: sanitizedQuery, candidates: pages)) ?? pages
        
        // 🛡️ 安全加固：对召回上下文执行 DLP 图像过滤，并注入金沙箱隔离包装
        let sandboxedContext = PromptSanitizer.shared.wrapInSandbox(context)
        let systemPrompt = contextBuilder.buildSystemPrompt(pages: rankedPages) + "\n\n" + sandboxedContext
  
        // 🔒 端侧 NER 脱敏 (SR-12)
        let (anonSystemPrompt, mapping1) = contextBuilder.anonymize(systemPrompt)
        let (anonQuery, mapping2) = contextBuilder.anonymize(sanitizedQuery, existingMapping: mapping1)
        
        var anonHistory: [ChatMessageDTO] = []
        var currentMapping = mapping2
        for msg in history {
            let (anonContent, nextMapping) = contextBuilder.anonymize(msg.content, existingMapping: currentMapping)
            currentMapping = nextMapping
            anonHistory.append(ChatMessageDTO(role: msg.role, content: anonContent))
        }
        
        // 4. 调用大模型，记录耗时指标并触发 RAG 自评估
        TaskCenter.shared.updateTask(taskID, status: .running(progress: 0.8, stage: .synthesis))
        let startTime = Date()
        let response = try await chatService.chat(systemPrompt: anonSystemPrompt, query: anonQuery, history: anonHistory)
        let latency = Int(Date().timeIntervalSince(startTime) * Double(UFPCore.SystemConstants.millisecondsPerSecond))
 
        // 🔓 端侧还原 (SR-12)
        let deanonymizedResponse = contextBuilder.deanonymize(response, mapping: currentMapping)
        
        analytics.recordRAGMetrics(query: sanitizedQuery, response: deanonymizedResponse, context: context, sources: capturedSources, systemPrompt: systemPrompt, modelName: configManager.model, latency: latency)
        
        TaskCenter.shared.completeTask(id: taskID)
        return ChatMessageDTO(role: .assistant, content: deanonymizedResponse)
    }
    
    /// 执行基于 AsyncStream 的高性能流式打字机问答
    /// - Parameters:
    ///   - query: 查询文本
    ///   - history: 历史消息记录
    ///   - pages: 候选知识库页面
    /// - Returns: 异步打字机字符串流
    func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        // UI 自动化测试模式下的自愈：模拟流式打字机延迟吐字，验证骨架屏 (Skeleton) 与流中止 (Stop-flow) 机制，规避 API 预检不通导致的测试失败
        if ProcessInfo.processInfo.arguments.contains(LLMConstants.UITesting.launchArg) {
            return runMockChatStream()
        }
        
        return AsyncThrowingStream { continuation in
            Task { @MainActor in
                guard configManager.isEnabled, let chatService = self.chatService else {
                    continuation.finish(throwing: LLMError.notConfigured)
                    return
                }
 
                let sanitizedQuery = PromptSanitizer.shared.sanitize(query)
                let taskID = TaskCenter.shared.addTask(type: .ai, name: LLMConstants.TaskName.aiChatStream, target: sanitizedQuery)
                
                defer {
                    TaskCenter.shared.completeTask(id: taskID)
                }
 
                do {
                    // 0. 连通性预检
                    try await performPreflightCheck()

                    // 1 & 2. 构建混合上下文，更新引用源，排序候选文档并脱敏 (SR-12)
                    let prep = try await prepareChatContextAndAnonymize(
                        sanitizedQuery: sanitizedQuery,
                        history: history,
                        pages: pages
                    )

                    var fullResponse = ""
                    // 初始化流式解码器
                    var deanonymizer = StreamDeanonymizer(mapping: prep.currentMapping)
                    
                    // 3. 消费打字机流片段
                    for try await chunk in chatService.streamChat(systemPrompt: prep.anonSystemPrompt, query: prep.anonQuery, history: prep.anonHistory) {
                        fullResponse += chunk
                        
                        // 🔓 流式端侧解密还原 (SR-12)
                        let processedChunk = deanonymizer.process(chunk: chunk)
                        if !processedChunk.isEmpty {
                            continuation.yield(processedChunk)
                        }
                    }
                    
                    let finalChunk = deanonymizer.finalize()
                    if !finalChunk.isEmpty {
                        continuation.yield(finalChunk)
                    }
 
                    // 4. 异步归档 RAG 精准度元数据以做治理评估，保存完整的原文以作归档
                    let fullDeanonymizedResponse = contextBuilder.deanonymize(fullResponse, mapping: prep.currentMapping)
                    analytics.recordRAGMetrics(query: sanitizedQuery, response: fullDeanonymizedResponse, context: prep.context, sources: prep.streamCapturedSources, systemPrompt: prep.systemPrompt, modelName: configManager.model, latency: 0)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
 
    /// 在 UI 自动化测试模式下生成 Mock 流式打字机回复数据
    /// - Returns: 模拟的 AsyncThrowingStream 字符串流
    private func runMockChatStream() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
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
 
    /// 执行连通性预检，发送极短请求验证 API 可达性
    /// - Throws: `LLMError.apiError` 或预检失败错误
    private func performPreflightCheck() async throws {
        let preflightClient = LLMClient(baseURL: configManager.baseURL, apiKey: configManager.apiKey)
        let preflightBody: [String: Any] = [
            LLMConstants.APIKey.model: configManager.model,
            LLMConstants.APIKey.messages: [[LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: LLMConstants.HealthCheck.prompt]],
            LLMConstants.APIKey.maxTokens: 1,
            LLMConstants.APIKey.temperature: 0
        ]
        do {
            _ = try await preflightClient.sendRequest(body: preflightBody)
        } catch {
            logger.error("[ChatRunner] 预检失败 — API 不可达", error: error)
            throw LLMError.apiError("LLM API : \(error.localizedDescription)")
        }
    }
 
    /// 临时存储 RAG 混合上下文及脱敏匿名化结果的容器结构体
    private struct ChatPreparationResult {
        let anonSystemPrompt: String
        let anonQuery: String
        let anonHistory: [ChatMessageDTO]
        let currentMapping: [String: String]
        let context: String
        let systemPrompt: String
        let streamCapturedSources: [KnowledgeSource]
    }
 
    /// 构建混合上下文并执行端侧 NER 脱敏匿名化
    /// - Parameters:
    ///   - sanitizedQuery: 经过清理的用户查询
    ///   - history: 历史消息列表
    ///   - pages: 候选知识页面列表
    /// - Returns: 处理完成的脱敏数据包
    private func prepareChatContextAndAnonymize(
        sanitizedQuery: String,
        history: [ChatMessageDTO],
        pages: [any KnowledgePageRepresentable]
    ) async throws -> ChatPreparationResult {
        // 1. 构建混合上下文，更新引用源
        let (context, sources) = await contextBuilder.buildRelevantContext(query: sanitizedQuery)
        SourceStore.shared.updateSources(sources)
        let streamCapturedSources = sources
        
        // 2. 排序候选文档
        let rankedPages = (try? await reranker.rerank(query: sanitizedQuery, candidates: pages)) ?? pages
        
        // 🛡️ 安全加固：对召回上下文执行 DLP 图像过滤，并注入金沙箱隔离包装
        let sandboxedContext = PromptSanitizer.shared.wrapInSandbox(context)
        let systemPrompt = contextBuilder.buildSystemPrompt(pages: rankedPages) + "\n\n" + sandboxedContext
 
        // 🔒 端侧 NER 脱敏 (SR-12)
        let (anonSystemPrompt, mapping1) = contextBuilder.anonymize(systemPrompt)
        let (anonQuery, mapping2) = contextBuilder.anonymize(sanitizedQuery, existingMapping: mapping1)
        
        var anonHistory: [ChatMessageDTO] = []
        var currentMapping = mapping2
        for msg in history {
            let (anonContent, nextMapping) = contextBuilder.anonymize(msg.content, existingMapping: currentMapping)
            currentMapping = nextMapping
            anonHistory.append(ChatMessageDTO(role: msg.role, content: anonContent))
        }
        
        return ChatPreparationResult(
            anonSystemPrompt: anonSystemPrompt,
            anonQuery: anonQuery,
            anonHistory: anonHistory,
            currentMapping: currentMapping,
            context: context,
            systemPrompt: systemPrompt,
            streamCapturedSources: streamCapturedSources
        )
    }
}

// MARK: - Stream Deanonymizer

/// 专属流式端侧解密还原器，负责在拼装出完整 [ENTITY_X] 占位符后，实时还原并输出 (SR-12)
struct StreamDeanonymizer: Sendable {
    private var buffer = ""
    private let mapping: [String: String]
    
    init(mapping: [String: String]) {
        self.mapping = mapping
    }
    
    /// 处理
    /// - Parameter chunk: 分块
    /// - Returns: 字符串
    mutating func process(chunk: String) -> String {
        var output = ""
        let text = buffer + chunk
        buffer = ""
        
        var currentIndex = text.startIndex
        while currentIndex < text.endIndex {
            // 查找潜在占位符的起始标识 '['
            if let openBracketRange = text[currentIndex...].range(of: "[") {
                // 先把 '[' 之前的常规文本直接输出
                output += text[currentIndex..<openBracketRange.lowerBound]
                
                // 查找对应的结束标识 ']'
                if let closeBracketRange = text[openBracketRange.upperBound...].range(of: "]") {
                    let placeholder = String(text[openBracketRange.lowerBound..<closeBracketRange.upperBound])
                    // 仅对匹配脱敏占位符前缀 [ENTITY_ 的方括号片段查 mapping 还原；
                    // 非前缀的普通方括号文本（如 Markdown 链接、代码块）直接输出，避免误还原 LLM 生成的字面量
                    if placeholder.hasPrefix(LLMConstants.Anonymization.placeholderPrefix),
                       let original = mapping[placeholder] {
                        output += original
                    } else {
                        // 非占位符或映射中不存在，直接输出原文
                        output += placeholder
                    }
                    currentIndex = closeBracketRange.upperBound
                } else {
                    // 没找到 ']'，说明可能占位符被分包切断了，剩下的缓存入 buffer
                    let remaining = String(text[openBracketRange.lowerBound...])
                    if remaining.count >= LLMConstants.EntityPlaceholder.maxRawLength {
                        // 长度超过合法占位符上限，说明这不是实体占位符，直接全部输出（不缓存，避免丢失 '[' 导致后续还原失败）
                        output += remaining
                    } else {
                        // 可能是合法占位符被切断，全部缓存等待下次拼接
                        buffer = remaining
                    }
                    break
                }
            } else {
                // 没有包含任何 '['，直接整体输出
                output += text[currentIndex...]
                break
            }
        }
        return output
    }
    
    /// finalize
    /// - Returns: 字符串
    mutating func finalize() -> String {
        let remaining = buffer
        return remaining
    }
}

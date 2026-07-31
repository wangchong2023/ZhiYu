//
//  LLMService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 LLM 模块的核心业务逻辑服务。
//
import Foundation
import Combine

/// AI 大模型调度门面中枢服务（LLMService）。
/// 负责协调与编排各项大语言模型（LLM）的底层子能力，维护全局 AI 运行生命周期及状态，
/// 它是整个系统所有 AI 能力与 RAG 检索管线的统一门面接口。
@MainActor
class LLMService: ObservableObject, LLMServiceProtocol, @unchecked Sendable {

    /// 全局唯一的线程安全单例实例。
    static let shared = LLMService()

    // MARK: - 注入依赖
    
    /// LLM 配置管理器，用以动态拉取 API Key、模型规格及服务器基准地址。
    @ObservationIgnored @Inject private var configManager: LLMConfigManager
    
    /// AI 指标分析服务，用以审计 Token 吞吐和响应耗时。
    @ObservationIgnored @Inject private var analytics: AIAnalyticsService
    
    // MARK: - 注入拆分后的底层子服务 (DIP 解耦)
    
    @ObservationIgnored @Inject private var chatRunner: any LLMChatServiceProtocol
    @ObservationIgnored @Inject private var ingestProcessor: any LLMKnowledgeServiceProtocol
    @ObservationIgnored @Inject private var queryReranker: any LLMRetrievalServiceProtocol

    // MARK: - UI 状态属性 (透传转发至 configManager)
    
    /// 当前所选的模型服务提供商（例如 OpenAI, Anthropic, Ollama 等）。
    /// 当前所选的模型服务提供商（例如 OpenAI, Anthropic, Ollama 等）。
    var provider: LLMProvider {
        get { configManager.provider }
        set { configManager.provider = newValue; objectWillChange.send() }
    }
    
    /// 安全的访问密钥 API Key。
    /// UI 自动化测试模式下自愈：拦截并返回测试专用的虚假 Key，解决测试环境因未填写密钥而阻断导入卡片交互的问题。
    var apiKey: String {
        get {
            if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                return "mock_api_key_for_testing"
            }
            return configManager.apiKey
        }
        set { configManager.apiKey = newValue; objectWillChange.send() }
    }
    
    /// API 调用的基础网关地址。
    var baseURL: String {
        get { configManager.baseURL }
        set { configManager.baseURL = newValue; objectWillChange.send() }
    }
    
    /// 大语言模型的具体代号规格（如 gpt-4o, claude-3-5-sonnet 等）。
    var model: String {
        get { configManager.model }
        set { configManager.model = newValue; objectWillChange.send() }
    }
    
    /// AI 模块是否处于开启状态。
    /// UI 自动化测试模式下自愈：强制返回开启状态，以便测试卡片可交互。
    var isEnabled: Bool {
        get {
            if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                return true
            }
            return configManager.isEnabled
        }
        set { configManager.isEnabled = newValue; objectWillChange.send() }
    }
    
    /// 是否开启后台自动化知识扫描与标签提取。
    var autoScan: Bool {
        get { configManager.autoScan }
        set { configManager.autoScan = newValue; objectWillChange.send() }
    }
    
    /// 是否使能后台智能重构分析与自动化双链链接发现。
    var autoRefactor: Bool {
        get { configManager.autoRefactor }
        set { configManager.autoRefactor = newValue; objectWillChange.send() }
    }

    /// 判断大模型所需的密钥、地址及开关是否已配置就绪。
    /// UI 自动化测试模式下自愈：默认返回就绪状态，确保 RAG 链路和导入入口彻底打通。
    var isReady: Bool {
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            return true
        }
        return configManager.isReady
    }

    // MARK: - 初始化
    
    /// 内部单例初始化构造方法。
    init() {
        // 在完成 DI 解析后，绑定刷新 Handler
        configManager.setRefreshHandler { [weak self] in
            self?.objectWillChange.send()
        }
    }

    // MARK: - LLMServiceProtocol 统一门面契约实现 (100% 委派转发)

    /// 生成
    /// - Parameter prompt: prompt
    /// - Parameter systemPrompt: systemPrompt
    /// - Returns: 字符串
    func generate(prompt: String, systemPrompt: String, maxTokens: Int = BusinessConstants.AI.maxOutputTokens) async throws -> String {
        try await chatRunner.generate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    }

    /// chat
    /// - Parameter query: query
    /// - Parameter history: history
    /// - Parameter pages: pages
    /// - Returns: 返回值
    func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        try await chatRunner.chat(query: query, history: history, pages: pages)
    }
 
    /// chatStream
    /// - Parameter query: query
    /// - Parameter history: history
    /// - Parameter pages: pages
    /// - Returns: 返回值
    func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        chatRunner.chatStream(query: query, history: history, pages: pages)
    }

    /// smart导入摄取
    /// - Parameter title: title
    /// - Parameter rawContent: rawContent
    /// - Parameter pages: pages
    /// - Returns: 返回值
    func smartIngest(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) async throws -> SmartIngestResultDTO {
        try await ingestProcessor.smartIngest(title: title, rawContent: rawContent, pages: pages)
    }

    /// discoverPotentialLinks
    /// - Parameter content: content
    /// - Parameter existingTitles: existingTitles
    /// - Returns: 列表
    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] {
        try await ingestProcessor.discoverPotentialLinks(content: content, existingTitles: existingTitles)
    }

    /// foldContent
    /// - Parameter existingContent: existingContent
    /// - Parameter newContent: newContent
    /// - Parameter title: title
    /// - Returns: 字符串
    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String {
        try await ingestProcessor.foldContent(existingContent: existingContent, newContent: newContent, title: title)
    }

    /// analyzeForRefactoring
    /// - Parameter pages: pages
    /// - Returns: 列表
    func analyzeForRefactoring(pages: [any KnowledgePageRepresentable]) async throws -> [RefactorSuggestionDTO] {
        try await ingestProcessor.analyzeForRefactoring(pages: pages)
    }

    /// rewriteQuery
    /// - Parameter query: query
    /// - Returns: 字符串
    func rewriteQuery(_ query: String) async -> String {
        await queryReranker.rewriteQuery(query)
    }

    /// expandQuery
    /// - Parameter query: query
    /// - Returns: 列表
    func expandQuery(_ query: String) async -> [String] {
        await queryReranker.expandQuery(query)
    }

    /// rerank
    /// - Parameter query: query
    /// - Parameter candidates: candidates
    /// - Returns: 列表
    func rerank(query: String, candidates: [any KnowledgePageRepresentable]) async throws -> [any KnowledgePageRepresentable] {
        try await queryReranker.rerank(query: query, candidates: candidates)
    }

    /// rerankChunks
    /// - Parameter query: query
    /// - Parameter chunks: chunks
    /// - Returns: 列表
    func rerankChunks(query: String, chunks: [PageChunk]) async -> [PageChunk] {
        await queryReranker.rerankChunks(query: query, chunks: chunks)
    }

    /// 生成HypotheticalDocument
    /// - Parameter query: query
    /// - Returns: 字符串
    func generateHypotheticalDocument(query: String) async -> String {
        await queryReranker.generateHypotheticalDocument(query: query)
    }

    /// AI 模块连通性与响应测速测试 — 同时验证非流式与流式信道。
    /// 阶段 1：非流式探活（generate "Hi" → 期望 "OK"）
    /// 阶段 2：流式信道验证（chatStream "ping" → 读取首个非空 chunk）
    /// 任一阶段失败均返回失败 ValidationResult 并携带错误信息。
    func validateAPIKey() async throws -> ValidationResult {
        let start = Date()
        var streamTested = false
        var streamOK = false

        do {
            // 阶段 1：非流式快速探活
            _ = try await generate(prompt: "Hi", systemPrompt: "Reply 'OK' only.")

            // 阶段 2：流式信道验证 — 确保聊天管道可用
            let stream = chatStream(query: "ping", history: [], pages: [])
            for try await chunk in stream where !chunk.isEmpty {
                    streamTested = true
                    streamOK = true
                    break
            }

            let latency = Int(Date().timeIntervalSince(start) * 1000)
            return ValidationResult(
                isSuccess: true,
                latencyMS: latency,
                streamTested: streamTested,
                streamOK: streamOK,
                errorCode: nil,
                errorMessage: nil
            )
        } catch {
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            var code = "ERR"
            if let llmErr = error as? LLMError {
                switch llmErr {
                case .unauthorized:
                    code = "401"
                case .httpError(let statusCode):
                    code = "\(statusCode)"
                case .rateLimited:
                    code = "429"
                default:
                    break
                }
            }
            return ValidationResult(
                isSuccess: false,
                latencyMS: latency,
                streamTested: streamTested,
                streamOK: streamOK,
                errorCode: code,
                errorMessage: error.localizedDescription
            )
        }
    }
}

// MARK: - 连通性支持子模型

extension LLMService {
    /// 代表大模型连通性检测响应的强类型实体 (ValidationResult)。
    struct ValidationResult {
        /// 连接是否畅通。
        let isSuccess: Bool
        /// 网关响应的总耗时（毫秒）。
        let latencyMS: Int
        /// 是否已执行流式信道验证。
        let streamTested: Bool
        /// 流式信道是否正常。
        let streamOK: Bool
        /// 异常错误代码（如有）。
        let errorCode: String?
        /// 具体的错误解析文案。
        let errorMessage: String?
    }
}

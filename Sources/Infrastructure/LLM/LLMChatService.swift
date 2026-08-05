//
//  LLMChatService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 LLMChat 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore

/// LLM 对话服务
/// 负责将系统提示词、用户查询及历史记录转换为 API 请求，并解析响应。
final class LLMChatService: Sendable {
    private let client: any LLMClientProtocol
    private let model: String
    private let logger: (any LoggerProtocol)?

    init(client: any LLMClientProtocol, model: String, logger: (any LoggerProtocol)? = nil) {
        self.client = client
        self.model = model
        self.logger = logger
    }

    // MARK: - 请求构造

    /// 构建标准对话消息数组
    private func buildChatMessages(systemPrompt: String, query: String, history: [ChatMessageDTO]) -> [[String: Any]] {
        // 注入回复篇幅控制指令，引导模型在可配区间内作答
        let lengthHint = "\nKeep response within \(PromptConstants.TokenLimits.defaultMaxOutputTokens) characters."
        let fullSystemPrompt = systemPrompt + PromptService.shared.languageInstruction + lengthHint
        var messages: [[String: Any]] = [[LLMConstants.APIKey.role: LLMConstants.Role.system, LLMConstants.APIKey.content: fullSystemPrompt]]
        
        // 注入历史记录
        for msg in history {
            messages.append([LLMConstants.APIKey.role: msg.role.rawValue, LLMConstants.APIKey.content: msg.content])
        }
        
        // 注入当前查询
        messages.append([LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: query])
        return messages
    }

    /// 构造非流式请求体
    private func makeChatRequestBody(systemPrompt: String, query: String, history: [ChatMessageDTO]) -> [String: Any] {
        [
            LLMConstants.APIKey.model: model,
            LLMConstants.APIKey.messages: buildChatMessages(systemPrompt: systemPrompt, query: query, history: history),
            LLMConstants.APIKey.temperature: AppConfig.AI.defaultTemperature,
            LLMConstants.APIKey.maxTokens: PromptConstants.TokenLimits.defaultMaxOutputTokens
        ]
    }

    /// 构造流式请求体
    private func makeStreamingRequestBody(systemPrompt: String, query: String, history: [ChatMessageDTO]) -> [String: Any] {
        var body = makeChatRequestBody(systemPrompt: systemPrompt, query: query, history: history)
        body[LLMConstants.APIKey.stream] = true
        return body
    }

    // MARK: - 对话执行

    /// 执行单次非流式对话
    func chat(systemPrompt: String, query: String, history: [ChatMessageDTO]) async throws -> String {
        let requestBody = makeChatRequestBody(systemPrompt: systemPrompt, query: query, history: history)
        let response = try await client.sendRequest(body: requestBody)
        
        guard let content = LLMUtils.extractContent(from: response) else {
            throw LLMError.invalidResponse
        }
        return content
    }

    private struct SendableBody: @unchecked Sendable {
        let dict: [String: Any]
    }

    /// 执行流式对话，返回异步抛出流
    func streamChat(systemPrompt: String, query: String, history: [ChatMessageDTO]) -> AsyncThrowingStream<String, Error> {
        let requestBody = makeStreamingRequestBody(systemPrompt: systemPrompt, query: query, history: history)
        let localClient = self.client
        
        let safeBody = SendableBody(dict: requestBody)
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        
        // 诊断日志：记录发送给模型的消息概览
        if let logger {
            let msgCount = (requestBody["messages"] as? [[String: Any]])?.count ?? 0
            let sysPreview = String(systemPrompt.prefix(LLMConstants.LogPreview.systemPromptLength))
            logger.debug("[LLMChat] 发送流式请求 — \(msgCount) 条消息, model=\(model)")
            logger.debug("[LLMChat] SystemPrompt(前\(LLMConstants.LogPreview.systemPromptLength)): \(sysPreview)")
            logger.debug("[LLMChat] Query: \(String(query.prefix(LLMConstants.LogPreview.queryLength)))")
        }

        let task = Task {
            do {
                let bytes = try await localClient.sendStreamingRequest(body: safeBody.dict)
                for try await chunk in SSEParser.parse(bytes: bytes, logger: logger) {
                    if Task.isCancelled { break }
                    continuation.yield(chunk)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        
        continuation.onTermination = { @Sendable _ in
            task.cancel()
        }
        
        return stream
    }
}

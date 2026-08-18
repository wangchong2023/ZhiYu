//
//  LLMAdapters.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：大语言模型客户端：多提供商适配、流式响应解析、端侧推理。
//
import Foundation

/// OpenAI 兼容适配器 (DeepSeek, SiliconFlow 等)
struct OpenAICompatibleAdapter: LLMAdapter {
    let id: String
    let displayName: String
    let config: LLMConfigStore

    /// 生成
    /// - Parameter prompt: prompt
    /// - Parameter systemPrompt: systemPrompt
    /// - Returns: 字符串
    func generate(prompt: String, systemPrompt: String) async throws -> String {
        let client = LLMClient(baseURL: config.baseURL, apiKey: config.apiKey)
        let body: [String: Any] = [
            LLMConstants.APIKey.model: config.model,
            LLMConstants.APIKey.messages: [
                [LLMConstants.APIKey.role: LLMConstants.Role.system, LLMConstants.APIKey.content: systemPrompt],
                [LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: prompt]
            ],
            LLMConstants.APIKey.temperature: 0.7
        ]
        let response = try await client.sendRequest(body: body)
        guard let choices = response["choices"] as? [[String: Any]],
              let content = (choices.first?["message"] as? [String: Any])?[LLMConstants.APIKey.content] as? String else {
            throw LLMError.invalidResponse
        }
        return content
    }

    /// chatStream
    /// - Parameter messages: messages
    /// - Returns: 返回值
    func chatStream(messages: [[String: Any]]) -> AsyncThrowingStream<String, Error> {
        let client = LLMClient(baseURL: config.baseURL, apiKey: config.apiKey)
        let body: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "stream": true
        ]

        struct SendableBody: @unchecked Sendable {
            let dict: [String: Any]
        }
        let safeBody = SendableBody(dict: body)
        let capturedClient = client

        return AsyncThrowingStream { @Sendable continuation in
            Task {
                do {
                    let bytes = try await capturedClient.sendStreamingRequest(body: safeBody.dict)
                    for try await chunk in SSEParser.parse(bytes: bytes) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

/// Ollama 本地适配器
struct OllamaAdapter: LLMAdapter {
    let id: String = "ollama"
    let displayName: String = "Ollama (Local)"
    let model: String
    let baseURL: String

    /// 生成
    /// - Parameter prompt: prompt
    /// - Parameter systemPrompt: systemPrompt
    /// - Returns: 字符串
    func generate(prompt: String, systemPrompt: String) async throws -> String {
        // 实现略，调用 Ollama API
        return "Ollama Result"
    }

    /// chatStream
    /// - Parameter messages: messages
    /// - Returns: 返回值
    func chatStream(messages: [[String: Any]]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in continuation.finish() }
    }
}

extension OpenAICompatibleAdapter: @unchecked Sendable {}

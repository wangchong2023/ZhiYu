//
//  ModelLabMocksDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：ModelLabManager 深度测试共享 Mock — 空响应 LLMService/LLMChatService，
//            强制 runSimulation 走 getMockResponse 离线路径。
//

import XCTest
import UFPCore
@testable import ZhiYu

// MARK: - 空响应 LLM Mock（强制 runSimulation 走 getMockResponse 离线路径）

/// 返回空字符串的 LLM Mock，使 runSimulation 中 realLLMResponse 为 nil，触发 getMockResponse 离线模拟。
@MainActor
final class EmptyResponseLLMService: LLMService, @unchecked Sendable {
    override func generate(prompt: String, systemPrompt: String, maxTokens: Int = PromptConstants.TokenLimits.defaultMaxOutputTokens) async throws -> String {
        return ""
    }
    override func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        ChatMessageDTO(role: .assistant, content: "")
    }
    override func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

/// 返回空字符串的 LLMChatService Mock，使 LLMService.shared.generate 经 chatRunner 委托后返回空。
@MainActor
final class EmptyResponseChatService: LLMChatServiceProtocol, @unchecked Sendable {
    var isEnabled: Bool = true
    var provider: LLMProvider = .custom
    var apiKey: String = ""
    var baseURL: String = ""
    var model: String = ""
    var autoScan: Bool = false
    var autoRefactor: Bool = false
    func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        ChatMessageDTO(role: .assistant, content: "")
    }
    func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func generate(prompt: String, systemPrompt: String, maxTokens: Int = PromptConstants.TokenLimits.defaultMaxOutputTokens) async throws -> String {
        return ""
    }
}

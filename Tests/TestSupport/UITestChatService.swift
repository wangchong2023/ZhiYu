//
//  UITestChatService.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试替身
//  核心职责：为显式启用离线数据的 UI 测试提供确定性对话响应。
//
import Foundation

@MainActor
final class UITestChatService: LLMChatServiceProtocol {
    var isEnabled: Bool { true }

    func generate(prompt: String, systemPrompt: String, maxTokens: Int) async throws -> String {
        LLMConstants.UITesting.mockNonStreamReply
    }

    func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        ChatMessageDTO(role: .assistant, content: LLMConstants.UITesting.mockRAGReply)
    }

    func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for chunk in LLMConstants.UITesting.mockStreamChunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}

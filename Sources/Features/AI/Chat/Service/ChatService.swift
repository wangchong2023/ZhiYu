//
//  ChatService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：实现 Chat 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
import Combine
import Dependencies

@MainActor
final class ChatService: ChatServiceProtocol {
    static let shared = ChatService()
    
    private let historyStore = ChatHistoryStore()
    @Dependency(\.llmService) private var llmService: any LLMServiceProtocol
    @Dependency(\.logger) private var logger: any LoggerProtocol

    private var cancellables = Set<AnyCancellable>()

    init() {
        AppEventBus.shared.subscribe()
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                if case .clearAllDataRequested = event {
                    self?.clearHistory()
                }
            }
            .store(in: &cancellables)
    }
    
    /// 加载History
    /// - Returns: 列表
    func loadHistory() -> [ChatMessage] {
        return historyStore.messages
    }
    
    /// 清除History
    func clearHistory() {
        historyStore.clear()
    }
    
    /// 保存UserMessage
    /// - Parameter content: content
    func saveUserMessage(_ content: String) {
        historyStore.append(ChatMessage(role: .user, content: content))
        // Bug #139 修复：user message 也需持久化，避免 App 崩溃时历史不完整
        historyStore.persistToDisk()
    }
    
    /// 保存AssistantMessage
    /// - Parameter content: content
    func saveAssistantMessage(_ content: String) {
        historyStore.append(ChatMessage(role: .assistant, content: content))
        historyStore.persistToDisk()
    }
    
    /// streamChat
    /// - Parameter query: query
    /// - Parameter pages: pages
    /// - Returns: 返回值
    func streamChat(query: String, pages: [KnowledgePage]) -> AsyncThrowingStream<String, Error> {
        logger.debug(" [ChatService] : \(query)")
        let history = Array(historyStore.recent(PromptConstants.TokenLimits.maxChatHistorySize))
        return llmService.chatStream(query: query, history: history, pages: pages)
    }
}

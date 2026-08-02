//
//  ChatCoordinator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：负责 Chat 业务流的导航路由与协作管理。
//
import SwiftUI
import Observation
import Combine

@MainActor
@Observable
final class ChatCoordinator {
    // ── 业务数据状态 ──
    var inputText = ""
    var insightfulQuestions: [String] = []
    var chatHistory: [ChatMessage] = []
    var isProcessing = false
    var streamingContent = ""
    
    // ── UI 交互状态 ──
    var isExporting = false
    var errorMessage: String?
    var showError = false
    var showLLMAlert = false
    var isGeneratingAIQuestions = false
    var showPrompts = false
    var exportURL: IdentifiableURL?
    var isSelectionMode = false
    var selectedMessageIDs: Set<UUID> = []
    var showClearConfirmation = false
    
    /// 预测的后续追问列表
    var predictedQuestions: [String] = []
    /// 是否正在生成预测问题
    var isGeneratingPredictedQuestions = false

    @ObservationIgnored @Inject private var aiSynthesis: (any AISynthesisServiceProtocol)
    @ObservationIgnored @Inject private var chatService: (any ChatServiceProtocol)
    @ObservationIgnored @Inject private var llmService: any LLMServiceProtocol
    @ObservationIgnored @Inject private var logger: any LoggerProtocol
    @ObservationIgnored @Inject private var perf: PerformanceService
    
    /// 当前流式请求的后台 Task，用于支持显式取消
    @ObservationIgnored private var currentStreamTask: Task<Void, Never>?

    init() {
        self.chatHistory = chatService.loadHistory()
    }

    // ── 业务动作 ──

    /// 加载InsightfulQuestions
    /// - Parameter pages: pages
    func loadInsightfulQuestions(pages: [KnowledgePage]) async {
        guard !pages.isEmpty && llmService.isEnabled && insightfulQuestions.isEmpty && !isGeneratingAIQuestions else { return }
        
        isGeneratingAIQuestions = true
        do {
            insightfulQuestions = try await aiSynthesis.generateInsightfulQuestions(pages: pages)
        } catch {
            insightfulQuestions = []
        }
        isGeneratingAIQuestions = false
    }

    /// 发送Message
    /// - Parameter query: query
    /// - Parameter pages: pages
    func sendMessage(query: String? = nil, pages: [KnowledgePage]) async {
        let rawText = (query ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else { return }

        // 用户输入长度保护：截断至 PromptConstants.TokenLimits.maxUserInputLength
        let text = String(rawText.prefix(PromptConstants.TokenLimits.maxUserInputLength))
        
        if isProcessing {
            cancelCurrentRequest()
            return
        }
        
        if query == nil { inputText = "" }
        errorMessage = nil
        predictedQuestions = [] // 清空旧的预测追问，避免在新输入过程中产生视觉干扰
        
        // 1. 保存并展示用户消息
        chatService.saveUserMessage(text)
        self.chatHistory.append(ChatMessage(role: .user, content: text))
        
        self.isProcessing = true
        self.streamingContent = ""
        
        // 2. 启动流式请求 Task，保存引用以支持显式取消
        currentStreamTask = Task { [weak self] in
            guard let self else { return }
            await self.runStreamTask(text: text, pages: pages)
        }
        
        // 等待流式 Task 完成
        await currentStreamTask?.value
    }

    /// 运行流式交互的核心后台 Task，处理大模型返回并完成数据保存
    /// - Parameters:
    ///   - text: 经过清洗的用户提问文本
    ///   - pages: 相关知识库页面
    private func runStreamTask(text: String, pages: [KnowledgePage]) async {
        do {
            _ = try await self.perf.measureAsync("chatStreamDelay") {
                let stream = self.chatService.streamChat(query: text, pages: pages)
                for try await chunk in stream {
                    // 检查 Task 是否已被取消（比 isProcessing 标志更可靠）
                    guard !Task.isCancelled else { break }
                    self.streamingContent += chunk
                }
            }
            
            // 只有在未被取消的情况下才保存结果并异步预测问题
            if !Task.isCancelled {
                self.chatService.saveAssistantMessage(self.streamingContent)
                self.chatHistory.append(ChatMessage(role: .assistant, content: self.streamingContent))
                
                // 异步启动预测用户后续问题的任务，不阻塞本次响应完成
                Task { [weak self] in
                    guard let self = self else { return }
                    await self.generatePredictedQuestions(pages: pages)
                }
            }
        } catch {
            if !Task.isCancelled {
                // 提供明确的错误反馈，包括 notConfigured 场景不再静默吞噬
                if case LLMError.notConfigured = error {
                    self.showLLMAlert = true
                } else {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
                self.logger.error(" [ChatCoordinator] 流式响应出错 ", error: error)
            }
        }
        
        // 无论成功或取消，都清理状态
        self.isProcessing = false
        self.streamingContent = ""
        self.currentStreamTask = nil
    }

    /// 取消Current请求
    func cancelCurrentRequest() {
        // 显式取消底层 Task，确保 AsyncThrowingStream 被终止
        currentStreamTask?.cancel()
        currentStreamTask = nil
        isProcessing = false
        // 清理残留的半截内容
        streamingContent = ""
    }

    /// 重新生成最后一次助手消息
    func regenerateLastMessage(pages: [KnowledgePage]) async {
        // 1. 寻找最后一次用户提问
        guard let lastUserMsgIndex = chatHistory.lastIndex(where: { $0.role == .user }) else { return }
        let lastUserQuery = chatHistory[lastUserMsgIndex].content
        
        // 2. 驱逐该提问后面的所有消息 (如已生成了一半的 AI 消息)
        if lastUserMsgIndex + 1 < chatHistory.count {
            chatHistory.removeSubrange((lastUserMsgIndex + 1)...)
        }
        
        // 3. 重新执行流式提问发送
        await sendMessage(query: lastUserQuery, pages: pages)
    }

    /// 清除ChatHistory
    func clearChatHistory() {
        chatService.clearHistory()
        chatHistory.removeAll()
        predictedQuestions.removeAll() // 清除历史时，同时重置预测追问问题
    }

    /// 导出Chat
    func exportChat() async {
        let history = isSelectionMode && !selectedMessageIDs.isEmpty ?
            chatHistory.filter { selectedMessageIDs.contains($0.id) } :
            chatHistory
            
        guard !history.isEmpty else { return }
        
        isExporting = true
        do {
            let md: String = history.map { msg in
                let role = msg.role == .user ? "You" : "AI"
                return "## \(role)\n\n\(msg.content)"
            }.joined(separator: "\n\n---\n\n")

            let url = try await WebViewExportService.shared.exportToPDF(markdown: md, fileName: "Chat_Export")
            self.exportURL = IdentifiableURL(url: url)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isExporting = false
    }

    /// 切换SelectionMode
    func toggleSelectionMode() {
        withAnimation {
            isSelectionMode.toggle()
            if !isSelectionMode {
                selectedMessageIDs.removeAll()
            }
        }
    }

    /// 切换MessageSelection
    /// - Parameter id: id
    func toggleMessageSelection(_ id: UUID) {
        if selectedMessageIDs.contains(id) {
            selectedMessageIDs.remove(id)
        } else {
            selectedMessageIDs.insert(id)
        }
        HapticFeedback.shared.trigger(.selection)
    }

    /// 根据当前对话的上下文，自动预测 3 个后续追问
    /// - Parameter pages: 相关知识库页面列表
    func generatePredictedQuestions(pages: [KnowledgePage]) async {
        guard !chatHistory.isEmpty && llmService.isEnabled && !isGeneratingPredictedQuestions else { return }
        
        isGeneratingPredictedQuestions = true
        do {
            predictedQuestions = try await aiSynthesis.predictFollowUpQuestions(history: chatHistory, pages: pages)
        } catch {
            predictedQuestions = []
            logger.error(" [ChatCoordinator] 预测后续问题失败: ", error: error)
        }
        isGeneratingPredictedQuestions = false
    }
}

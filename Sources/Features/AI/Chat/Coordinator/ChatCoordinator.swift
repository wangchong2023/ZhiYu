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
import UFPCore
import ZhiYuDomain
import Observation
import Combine
import Dependencies

@MainActor
@Observable
final class ChatCoordinator {
    // ── 业务数据状态 ──
    var inputText = ""
    var insightfulQuestions: [String] = []
    var chatHistory: [ChatMessage] = []

    /// 异步任务状态真值源（统一承载 loading 与 failure，替代 isProcessing/errorMessage/showError 三件套）
    var status: AsyncStatus<Void> = .idle
    var streamingContent = ""
    
    // ── UI 交互状态 ──
    var isExporting = false
    /// 是否处理中（由 status 派生，兼容 View/测试读取）
    var isProcessing: Bool { status.isLoading }
    /// 当前错误消息（由 status.failure 派生，兼容 View/测试读取）
    var errorMessage: String? { status.errorMessage }
    /// 是否展示错误弹窗（由 status.failure 派生，提供 setter 供 alert 绑定关闭）
    var showError: Bool {
        get { status.errorMessage != nil }
        set {
            if !newValue, status.errorMessage != nil { status = .idle }
        }
    }
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

    @ObservationIgnored @Dependency(\.aiSynthesisService) private var aiSynthesis: any AISynthesisServiceProtocol
    @ObservationIgnored @Dependency(\.chatService) private var chatService: any ChatServiceProtocol
    @ObservationIgnored @Dependency(\.llmService) private var llmService: any LLMServiceProtocol
    @ObservationIgnored @Dependency(\.logger) private var logger: any LoggerProtocol
    @ObservationIgnored @Dependency(\.performanceService) private var perf: PerformanceService
    
    /// 当前流式请求的后台 Task，用于支持显式取消
    @ObservationIgnored private var currentStreamTask: Task<Void, Never>?
    /// 对话历史代次计数器（每次新发送/清史/重新生成递增，防止旧流或旧预测追问跨会话回写污染）
    @ObservationIgnored private var historyGeneration: UInt64 = 0

    init() {
        self.chatHistory = chatService.loadHistory()
    }

    // ── 业务动作 ──

    /// 加载InsightfulQuestions
    /// - Parameter pages: pages
    /// - Parameter forceRefresh: 是否强制刷新（忽略已有问题）
    func loadInsightfulQuestions(pages: [KnowledgePage], forceRefresh: Bool = false) async {
        guard !pages.isEmpty && llmService.isEnabled && (forceRefresh || insightfulQuestions.isEmpty) && !isGeneratingAIQuestions else { return }
        
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
        historyGeneration &+= 1
        let capturedGeneration = historyGeneration
        status = .idle // 清空旧错误/加载状态
        predictedQuestions = [] // 清空旧的预测追问，避免在新输入过程中产生视觉干扰
        
        // 1. 保存并展示用户消息
        chatService.saveUserMessage(text)
        self.chatHistory.append(ChatMessage(role: .user, content: text))
        
        self.status = .loading(L10n.Chat.aiRunning)
        self.streamingContent = ""
        
        // 2. 启动流式请求 Task，保存引用以支持显式取消
        currentStreamTask = Task { [weak self] in
            guard let self else { return }
            await self.runStreamTask(text: text, pages: pages, generation: capturedGeneration)
        }
        
        // 等待流式 Task 完成
        await currentStreamTask?.value
    }

    /// 运行流式交互的核心后台 Task，处理大模型返回并完成数据保存
    /// - Parameters:
    ///   - text: 经过清洗的用户提问文本
    ///   - pages: 相关知识库页面
    ///   - generation: 发送时的对话历史代次，用于拦截清史/重试后的过时回写
    private func runStreamTask(text: String, pages: [KnowledgePage], generation: UInt64) async {
        do {
            _ = try await self.perf.measureAsync("chatStreamDelay") {
                let stream = self.chatService.streamChat(query: text, pages: pages)
                for try await chunk in stream {
                    // 检查 Task 是否已被取消或历史代次已变更
                    guard !Task.isCancelled, self.historyGeneration == generation else { break }
                    self.streamingContent += chunk
                }
            }
            
            // 只有在未被取消、处于同一代次且流式内容非空时才保存助手回复，防止空流污染对话历史
            if !Task.isCancelled && self.historyGeneration == generation {
                self.finalizeStreamResponse(pages: pages)
            }
            // 成功结束（含未取消分支）：复位为 idle
            if self.historyGeneration == generation {
                self.status = .idle
            }
        } catch {
            if !Task.isCancelled && self.historyGeneration == generation {
                // 提供明确的错误反馈，包括 notConfigured 场景不再静默吞噬
                if case LLMError.notConfigured = error {
                    self.showLLMAlert = true
                    self.status = .idle
                } else {
                    self.status = .failure(error.localizedDescription)
                }
                self.logger.error(" [ChatCoordinator] 流式响应出错 ", error: error)
            } else if self.historyGeneration == generation {
                self.status = .idle
            }
        }
        
        // 仅清理属于当前代次的残留半截内容与任务引用
        if self.historyGeneration == generation {
            self.streamingContent = ""
            self.currentStreamTask = nil
        }
    }

    /// 落盘非空流式助手回复并异步触发后续追问预测
    private func finalizeStreamResponse(pages: [KnowledgePage]) {
        let finalContent = streamingContent
        guard !finalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        chatService.saveAssistantMessage(finalContent)
        chatHistory.append(ChatMessage(role: .assistant, content: finalContent))
        Task { [weak self] in
            guard let self else { return }
            await self.generatePredictedQuestions(pages: pages)
        }
    }

    /// 取消Current请求
    func cancelCurrentRequest() {
        // 显式取消底层 Task，确保 AsyncThrowingStream 被终止
        currentStreamTask?.cancel()
        currentStreamTask = nil
        status = .idle
        // 清理残留的半截内容
        streamingContent = ""
    }

    /// 重新生成最后一次助手消息
    func regenerateLastMessage(pages: [KnowledgePage]) async {
        // 0. 若当前仍在流式生成，先中止旧流，防止后续 sendMessage 命中 isProcessing 早退导致用户消息丢失
        if isProcessing {
            cancelCurrentRequest()
        }

        // 1. 寻找最后一次用户提问
        guard let lastUserMsgIndex = chatHistory.lastIndex(where: { $0.role == .user }) else { return }
        let lastUserQuery = chatHistory[lastUserMsgIndex].content

        // 2. 保留至用户提问（不含），驱逐该提问及后面的所有消息
        let retainedHistory = Array(chatHistory[..<lastUserMsgIndex])

        // 3. 同步更新内存与持久化（清空后重写保留部分，sendMessage 会重新保存用户提问）
        historyGeneration &+= 1
        chatHistory = retainedHistory
        chatService.clearHistory()
        for msg in retainedHistory {
            if msg.role == .user {
                chatService.saveUserMessage(msg.content)
            } else {
                chatService.saveAssistantMessage(msg.content)
            }
        }

        // 4. 重新执行流式提问发送
        await sendMessage(query: lastUserQuery, pages: pages)
    }

    /// 清除ChatHistory（同步取消进行中的流式请求并推进代次，防止旧回复幽灵回写）
    func clearChatHistory() {
        historyGeneration &+= 1
        cancelCurrentRequest()
        chatService.clearHistory()
        chatHistory.removeAll()
        predictedQuestions.removeAll() // 清除历史时，同时重置预测追问问题
        isSelectionMode = false
        selectedMessageIDs.removeAll()
    }

    /// 导出Chat（含并发防重入守卫）
    func exportChat() async {
        guard !isExporting else { return }
        let history = isSelectionMode && !selectedMessageIDs.isEmpty ?
            chatHistory.filter { selectedMessageIDs.contains($0.id) } :
            chatHistory
            
        guard !history.isEmpty else { return }
        
        isExporting = true
        defer { isExporting = false }
        do {
            let md: String = history.map { msg in
                let role = msg.role == .user ? L10n.Chat.exportRoleUser : L10n.Chat.exportRoleAI
                return "## \(role)\n\n\(msg.content)"
            }.joined(separator: "\n\n---\n\n")

            let url = try await WebViewExportService.shared.exportToPDF(markdown: md, fileName: L10n.Chat.exportFileName)
            self.exportURL = IdentifiableURL(url: url)
        } catch {
            status = .failure(error.localizedDescription)
        }
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
        
        let capturedGeneration = historyGeneration
        isGeneratingPredictedQuestions = true
        defer { isGeneratingPredictedQuestions = false }
        do {
            let questions = try await aiSynthesis.predictFollowUpQuestions(history: chatHistory, pages: pages)
            guard historyGeneration == capturedGeneration && !chatHistory.isEmpty else { return }
            predictedQuestions = questions
        } catch {
            if historyGeneration == capturedGeneration {
                predictedQuestions = []
            }
            logger.error(" [ChatCoordinator] 预测后续问题失败: ", error: error)
        }
    }
}

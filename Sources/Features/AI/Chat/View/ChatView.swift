//
//  ChatView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 Chat 界面的 UI 视图层组件。
//
import SwiftUI
import Dependencies
#if canImport(WebKit)
import WebKit
#endif

// MARK: - 导航入口
struct ChatView: View {
    @Binding var selectedTab: AppTab
    var body: some View {
        ChatViewContent(selectedTab: $selectedTab)
    }
}

// MARK: - 视图核心
struct ChatViewContent: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @EnvironmentObject var llmService: LLMService
    @Dependency(\.promptService) private var promptService
    @Dependency(\.taskCenter) private var taskCenter
    @Binding var selectedTab: AppTab
    
    // 使用协调器管理状态与交互
    @State private var coordinator = ChatCoordinator()
    @Environment(\.interfaceIdiom) private var idiom
    
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            PageBackgroundView(accentColor: .appAccent)
                .ignoresSafeArea()
                
            VStack(spacing: 0) {
                chatMessageList

                chatInputBar
            }
        }
        .appTabToolbar(title: "") {
            chatMenu
        }
        .skipOnWatch { $0.sheet(item: $coordinator.exportURL) { identifiable in
            ActivityView(activityItems: [identifiable.url])
        } }
        .alert(L10n.Common.error, isPresented: $coordinator.showError) {
            Button(L10n.Common.ok) { coordinator.errorMessage = nil }
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
        .alert(L10n.Common.configureAI, isPresented: $coordinator.showLLMAlert) {
            Button(L10n.ModelManager.Lab.configurations) {
                HapticFeedback.shared.trigger(.selection)
                router.isShowingAISettingsSheet = true
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Common.configureAI)
        }
        .confirmationDialog(
            L10n.Chat.clearHistoryConfirmTitle,
            isPresented: $coordinator.showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Common.delete, role: .destructive) {
                coordinator.clearChatHistory()
            }
            Button(L10n.Common.cancel, role: .cancel) { }
        } message: {
            Text(L10n.Chat.clearHistoryConfirmMessage)
        }
        .task {
            await coordinator.loadInsightfulQuestions(pages: store.pages)
            
            // MARK: - [Cold Start Aha Moment] 自动识别并投递向导提问 Prompt
            if let prompt = router.pendingInitialChatPrompt, !prompt.isEmpty {
                // 立即清空，确保该 Prompt 在整个生命周期中仅被单次且安全消费
                router.pendingInitialChatPrompt = nil
                
                // 自动装填至对话框
                coordinator.inputText = prompt
                
                // 阻尼等待，保证过渡过渡的弹性动效平滑呈现
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                // 即刻触发 RAG 检索回答流
                await coordinator.sendMessage(pages: store.pages)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
    
    @ViewBuilder
    private var chatMenu: some View {
        if idiom != .watch {
            Menu {
                Section {
                    Button(action: { }) {
                        Label("\(coordinator.chatHistory.count) \(L10n.AI.LLM.messages)", systemImage: DesignSystem.Icons.chatBubble)
                    }
                    .disabled(true)
                    
                    Button(role: .destructive, action: { 
                        coordinator.showClearConfirmation = true
                    }) {
                        Label(L10n.AI.LLM.clearHistory, systemImage: DesignSystem.Icons.delete)
                    }
                }
                
                Section {
                    NavigationLink(destination: PromptWorkshopView()) {
                        Label(L10n.Settings.promptSettings, systemImage: "sparkles.rectangle.stack")
                    }
                }
                
                if !coordinator.chatHistory.isEmpty {
                    Section(L10n.Chat.exportConversation) {
                        Button(action: {
                            coordinator.toggleSelectionMode()
                        }) {
                            Label(coordinator.isSelectionMode ? L10n.Common.done : L10n.Chat.selectToExport, systemImage: coordinator.isSelectionMode ? DesignSystem.Icons.checkCircle : DesignSystem.Icons.checklist)
                        }

                        Button(action: {
                            Task { await coordinator.exportChat() }
                        }) {
                            Label(coordinator.isSelectionMode && !coordinator.selectedMessageIDs.isEmpty ? L10n.Chat.exportSelectedPDF : L10n.Chat.exportPDF, systemImage: DesignSystem.Icons.docRichtext)
                        }
                    }
                }
            } label: {
                Image(systemName: DesignSystem.Icons.more)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.appSecondary)
            }
            .buttonStyle(.plain)  // 消除 Toolbar 中 Menu 的 bordered 白色背景
        }
    }
    
    private var chatMessageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DesignSystem.medium) {
                    if coordinator.chatHistory.isEmpty && !coordinator.isProcessing {
                        ChatWelcomeView()
                            .environment(coordinator)
                    } else {
                        if coordinator.isProcessing {
                            streamingBubble.id("processing")
                        } else {
                            // 当非生成状态且有后续预测追问时，在此处渲染追问按钮气泡
                            predictedQuestionsView
                        }
                        ForEach(coordinator.chatHistory.reversed()) { message in
                            messageRow(for: message)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.tiny)
                .padding(.bottom, DesignSystem.standardPadding)
            }
            .scrollIndicators(.hidden)
            // 绑定测试标识符，便于自动化 UI 冒烟测试快速抓取
            .accessibilityIdentifier("ChatMessage_List")
            .onChange(of: coordinator.streamingContent) { _, _ in
                // 在流式文本输入增长时，平滑滚动至焦点气泡，利用 easeOut 阻尼有效消除视图震颤
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("processing", anchor: .bottom)
                }
            }
            .onChange(of: coordinator.isProcessing) { _, isProcessing in
                if isProcessing {
                    // 开始生成时，将视图焦点以弹性动画推至处理气泡
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        proxy.scrollTo("processing", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func messageRow(for message: ChatMessage) -> some View {
        let isLastAssistant = message.role == .assistant && coordinator.chatHistory.last?.id == message.id && !coordinator.isProcessing
        ChatBubbleView(
            message: message, 
            pages: store.pages, 
            selectedTab: $selectedTab,
            isSelectionMode: coordinator.isSelectionMode,
            isSelected: coordinator.selectedMessageIDs.contains(message.id),
            onRegenerate: isLastAssistant ? {
                Task {
                    await coordinator.regenerateLastMessage(pages: store.pages)
                }
            } : nil,
            predictedQuestions: isLastAssistant ? coordinator.predictedQuestions : [],
            onSelectQuestion: { question in
                Task {
                    await coordinator.sendMessage(query: question, pages: store.pages)
                }
            }
        )
        .id(message.id)
        .overlay {
            if coordinator.isSelectionMode {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        coordinator.toggleMessageSelection(message.id)
                    }
            }
        }
    }
    
    private var streamingBubble: some View {
        HStack(alignment: .top, spacing: DesignSystem.tightPadding) {
            Image(systemName: DesignSystem.Icons.thinking)
                .font(DesignSystem.secondaryFont)
                .foregroundStyle(.appAccent)
                .frame(width: DesignSystem.titleIconSize * DesignSystem.Domain.AI.Chat.bubbleIconScale, height: DesignSystem.titleIconSize * DesignSystem.Domain.AI.Chat.bubbleIconScale)
                .background(Color.appAccent.opacity(SystemOpacity.glass))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: DesignSystem.tiny + DesignSystem.atomic) {
                if coordinator.streamingContent.isEmpty {
                    // 获取当前活跃任务的阶段
                    let stage: TaskStage = {
                        if let runningTask = taskCenter.tasks.first(where: { if case .running = $0.status { return true }; return false }) {
                            if case .running(_, let stage) = runningTask.status {
                                return stage
                            }
                        }
                        return .general
                    }()
                    
                    AppAILoadingSkeleton(stage: stage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    MarkdownRendererView(content: coordinator.streamingContent, isPrivate: false, onLinkTap: { _ in }, isCompact: true)
                        .padding(DesignSystem.medium)
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius))
                }
                
                // 一键中断(Stop)生成按钮
                Button(action: {
                    // 主动调用协调器取消当前的流式大模型请求
                    coordinator.cancelCurrentRequest()
                    // 触发系统的选择触觉反馈，提升交互感知
                    HapticFeedback.shared.trigger(.selection)
                }) {
                    HStack(spacing: DesignSystem.atomic) {
                        Image(systemName: DesignSystem.Icons.stopFill)
                            .font(.system(size: 11, weight: .bold)) // Dynamic Type
                        Text(L10n.Common.cancel)
                            .font(.system(size: 11, weight: .semibold)) // Dynamic Type
                    }
                    .padding(.horizontal, Spacing.Chip.horizontalPadding)
                    .padding(.vertical, DesignSystem.atomic)
                    .foregroundStyle(Color.theme.red)
                    .background(Color.theme.red.opacity(DesignSystem.Opacity.glass))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, DesignSystem.tiny)
            }
            Spacer(minLength: ComponentSpacing.iconStandard)
        }
    }
    
    private var chatInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .center, spacing: DesignSystem.medium) {
                Button(action: { coordinator.showPrompts.toggle() }) {
                    Image(systemName: DesignSystem.Icons.promptLibrary).font(.title3)
                        .foregroundStyle(coordinator.isProcessing ? .appSecondary.opacity(DesignSystem.Opacity.disabled) : .appAccent)
                        .frame(width: DesignSystem.Action.buttonHeight, height: DesignSystem.Action.buttonHeight)
                        .background(Color.appCard).clipShape(Circle())
                }
                .buttonStyle(.plain).disabled(coordinator.isProcessing)
                
                TextField(coordinator.isProcessing ? L10n.Chat.aiRunning : L10n.Chat.inputPlaceholder, text: $coordinator.inputText)
                    .font(.subheadline).focused($isInputFocused)
                    .foregroundStyle(coordinator.isProcessing ? .appSecondary : .appText).textFieldStyle(.plain)
                    .disabled(coordinator.isProcessing).submitLabel(.send)
                    // 绑定测试标识符，便于自动化 UI 冒烟测试智能装填问答 Prompt
                    .accessibilityIdentifier("ChatInput_TextField")
                    .onSubmit { if canSend { Task { await coordinator.sendMessage(pages: store.pages) } } }
                
                Button { 
                    if coordinator.isProcessing { coordinator.cancelCurrentRequest() } else { HapticFeedback.shared.trigger(.selection); Task { await coordinator.sendMessage(pages: store.pages) } }
                } label: {
                    Image(systemName: coordinator.isProcessing ? DesignSystem.Icons.stop : DesignSystem.Icons.send)
                        .font(.title2).foregroundStyle(coordinator.isProcessing ? .red : (canSend ? .appAccent : .appSecondary))
                        .symbolEffect(.bounce, value: coordinator.isProcessing)
                        .frame(width: DesignSystem.Action.inputBarHeight, height: DesignSystem.Action.inputBarHeight)
                }
                // 绑定测试标识符，便于自动化 UI 冒烟测试一键触发或物理取消 RAG 对话流
                .accessibilityIdentifier("ChatSend_Button")
                .disabled(!canSend && !coordinator.isProcessing)
            }
            .padding(.horizontal, DesignSystem.standardPadding).padding(.vertical, DesignSystem.tightPadding)
            .background(coordinator.isProcessing ? Color.appCard.opacity(DesignSystem.Opacity.soft) : Color.appCard)
            .sheet(isPresented: $coordinator.showPrompts) {
                NavigationStack {
                    ChatWelcomeView(isSheet: true)
                        .environment(coordinator)
                        .navigationTitle(L10n.Chat.explorationAndPrompts)
.appNavigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .automatic) { Button(L10n.Common.close) { coordinator.showPrompts = false } } }
                }
                .presentationDetents([.large])
            }
        }
    }
    
    private var canSend: Bool {
        !coordinator.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !coordinator.isProcessing
    }

    /// 渲染根据上下文预测的用户后续可能追问的气泡按钮列表
    private var predictedQuestionsView: some View {
        Group {
            if !coordinator.isProcessing,
               let lastMessage = coordinator.chatHistory.last,
               lastMessage.role == .assistant,
               !coordinator.predictedQuestions.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.tightPadding) {
                            ForEach(coordinator.predictedQuestions, id: \.self) { question in
                                Button(action: {
                                    // 触发系统的轻微选择触感反馈
                                    HapticFeedback.shared.trigger(.selection)
                                    Task {
                                        // 一键直接追问
                                        await coordinator.sendMessage(query: question, pages: store.pages)
                                    }
                                }) {
                                    HStack(spacing: DesignSystem.tiny) {
                                        Image(systemName: "arrow.up.right.bubble")
                                            .font(.caption)
                                            .foregroundStyle(.appAccent)
                                        Text(question)
                                            .font(.system(size: DesignSystem.captionFontSize, weight: .medium))
                                            .foregroundStyle(.appText)
                                    }
                                    .padding(.horizontal, DesignSystem.standardPadding)
                                    .padding(.vertical, Spacing.Chip.horizontalPadding)
                                    .background(Color.appCard.opacity(DesignSystem.Opacity.glass))
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                                            .stroke(Color.appBorder.opacity(DesignSystem.Opacity.subtle), lineWidth: DesignSystem.borderWidth)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, DesignSystem.standardPadding)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                .padding(.vertical, DesignSystem.tiny)
            }
        }
    }
}

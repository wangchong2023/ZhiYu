//
//  ModelLabChatPanel.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：多轮对话沙盒视图，包含消息气泡流滚动列表、流式生成占位、底部输入栏与发送/停止按键，
//  以及对话消息的异步推理调度逻辑。
//

import SwiftUI
import UFPDesignSystem

// MARK: - 多轮对话沙盒

extension ModelLabView {

    /// 多轮对话聊天沙盒视图
    @ViewBuilder
    var aiChatSandboxView: some View {
        // 大模型选择与参数配置栏
        modelAndConfigControlBar(for: .aiChat)

        // 实时性能评估看板
        metricsMonitorBoard

        // 聊天对话列表与气泡流
        chatMainPanel
    }

    @ViewBuilder
    var chatMainPanel: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            messageScrollView
            Divider()
            chatInputBarView
        }
        .cardStyle(horizontalPadding: DesignTokens.Spacing.medium, verticalPadding: DesignTokens.Spacing.medium)
    }

    @ViewBuilder
    var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    if chatHistory.isEmpty && !labManager.isGenerating {
                        chatQuickSuggestionsView
                    }

                    ForEach(chatHistory) { msg in
                        AIChatBubbleView(
                            text: msg.text,
                            isUser: msg.isUser,
                            metricsBadgeText: msg.metricsBadgeText
                        )
                        .id(msg.id)
                    }

                    // 正在流式生成时的临时显示占位符（使用共享 AI 思考中与打字气泡）
                    if labManager.isGenerating {
                        generatingPlaceholderView
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.small)
            }
            .frame(maxHeight: .infinity) // 消息滚动区域自适应撑满，使底部输入框贴合安全区
            .onChange(of: chatHistory) { _, _ in
                if let last = chatHistory.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: labManager.generatedText) { _, _ in
                if labManager.isGenerating {
                    withAnimation { proxy.scrollTo("generating_anchor", anchor: .bottom) }
                }
            }
            .onChange(of: labManager.isGenerating) { _, isGen in
                if isGen {
                    withAnimation { proxy.scrollTo("generating_anchor", anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private var chatQuickSuggestionsView: some View {
        let suggestions = [
            L10n.ModelManager.Lab.Chat.suggestSwift,
            L10n.ModelManager.Lab.Chat.suggestRAG,
            L10n.ModelManager.Lab.Chat.suggestSummary
        ]

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                Image(systemName: DesignTokens.Icons.sparkles)
                    .font(.caption)
                    .foregroundStyle(Color.theme.cyan)
                Text(L10n.ModelManager.Lab.Chat.suggestionsTitle)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    HapticFeedback.shared.trigger(.selection)
                    chatInputText = suggestion
                    sendChatMessage()
                } label: {
                    HStack {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundStyle(.appText)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: DesignTokens.Icons.arrowUpRight)
                            .font(.caption2)
                            .foregroundStyle(Color.theme.cyan)
                    }
                    .padding(DesignTokens.Spacing.standardPadding)
                    .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
                    .cornerRadius(DesignTokens.SystemRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small)
                            .stroke(Color.theme.cyan.opacity(DesignTokens.Opacity.subtle), lineWidth: DesignTokens.SystemStroke.divider)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.small)
    }

    @ViewBuilder
    private var generatingPlaceholderView: some View {
        let liveBadge = labManager.currentStats.speed > 0
            ? L10n.ModelManager.Lab.Chat.metricsBadgeFormat(labManager.currentStats.firstTokenLatency, labManager.currentStats.speed)
            : nil
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            if labManager.generatedText.isEmpty {
                AIThinkingBubbleView(customText: labManager.loadingStageText.isEmpty ? nil : labManager.loadingStageText)
            } else {
                let parsed = ThinkingContentParser.parse(rawText: labManager.generatedText)
                if let thought = parsed.thinkingText {
                    ThinkingCollapsibleView(thinkingText: thought, isStreaming: labManager.isGenerating)
                }
                if !parsed.answerText.isEmpty || parsed.thinkingText == nil {
                    AIChatBubbleView(
                        text: parsed.thinkingText == nil ? labManager.generatedText : parsed.answerText,
                        isUser: false,
                        metricsBadgeText: liveBadge
                    )
                }
            }
        }
        .id("generating_anchor")
    }

    @ViewBuilder
    var chatInputBarView: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.small) {
            // 左侧特化附件（加号）菜单按钮，根据不同用例由 ModelLabManager 状态层分发不同选项，避开 View 本地化审计
            Menu {
                Group {
                    ForEach(labManager.attachmentOptions) { option in
                        Button(action: {
                            HapticFeedback.shared.trigger(.selection)
                            toastManager.show(type: .success, message: option.successMessage)
                        }) {
                            Label(option.title, systemImage: option.icon)
                        }
                    }
                }
                .labelStyle(.titleAndIcon)
            } label: {
                Image(systemName: DesignTokens.Icons.plus)
                    .font(.title2)
                    .foregroundStyle(Color.theme.cyan)
                    .frame(width: DesignSystem.Action.inputBarHeight, height: DesignSystem.Action.inputBarHeight)
            }
            .buttonStyle(.plain)

            // Thinking Mode 快捷开关（对齐 Google AI Edge Gallery AI Chat 思考模式一键切换）
            Button {
                HapticFeedback.shared.trigger(.selection)
                enableThinking.toggle()
            } label: {
                HStack(spacing: DesignTokens.Spacing.atomic) {
                    Image(systemName: DesignTokens.Icons.sparkles)
                        .font(.caption.weight(.semibold))
                    Text(L10n.ModelManager.Lab.enableThinking)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(enableThinking ? Color.theme.white : .appSecondary)
                .padding(.horizontal, DesignTokens.Spacing.small)
                .padding(.vertical, DesignTokens.Spacing.tiny)
                .background(enableThinking ? Color.appAccent : Color.appBorder.opacity(DesignTokens.Opacity.glass))
                .clipShape(Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("toggleThinkingModeButton")

            TextField(labManager.isGenerating ? L10n.Chat.aiRunning : L10n.ModelManager.Lab.chatInputPlaceholder, text: $chatInputText)
                .font(.subheadline)
                .foregroundStyle(labManager.isGenerating ? Color.secondary : Color.theme.text)
                .textFieldStyle(.plain)
                .disabled(labManager.isGenerating)
                .submitLabel(.send)
                .onSubmit {
                    if !chatInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        sendChatMessage()
                    }
                }

            Button {
                if labManager.isGenerating {
                    labManager.stopSimulation()
                } else {
                    HapticFeedback.shared.trigger(.selection)
                    sendChatMessage()
                }
            } label: {
                Image(systemName: labManager.isGenerating ? DesignTokens.Icons.stop : DesignTokens.Icons.send)
                    .font(.title2)
                    .foregroundStyle(labManager.isGenerating ? .red : (!chatInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.theme.cyan : .secondary))
                    .frame(width: DesignSystem.Action.inputBarHeight, height: DesignSystem.Action.inputBarHeight)
            }
            .disabled(chatInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !labManager.isGenerating)
        }
        .commonContentPadding(horizontal: DesignTokens.Spacing.standardPadding, vertical: DesignTokens.Spacing.tightPadding)
        .background(labManager.isGenerating ? Color.appCard.opacity(DesignTokens.Opacity.soft) : Color.appCard)
    }

    // MARK: - 对话逻辑

    func sendChatMessage() {
        let text = chatInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty && !labManager.isGenerating else { return }

        // 1. 追加用户消息
        let userMsg = LabChatMessage(isUser: true, text: text)
        chatHistory.append(userMsg)
        chatInputText = ""

        // 2. 异步启动推理
        Task {
            guard let model = getActiveModel() else { return }
            HapticFeedback.shared.trigger(.selection)
            // 调用 ModelLabManager（优先真实 LiteRT-LM / FoundationModels 端侧流式推理，无权重时降级）
            await labManager.runSimulation(
                for: .aiChat,
                model: model,
                prompt: text,
                enableThinking: enableThinking
            )

            // 推理结束后，把流式生成的文本转入历史对话消息，并清空生成缓冲区
            let aiMsg = LabChatMessage(
                isUser: false,
                text: labManager.generatedText,
                firstTokenLatencyMs: labManager.currentStats.firstTokenLatency,
                tokensPerSecond: labManager.currentStats.speed
            )
            chatHistory.append(aiMsg)
            labManager.generatedText = ""
        }
    }
}

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
        VStack(spacing: DesignSystem.medium) {
            messageScrollView
            Divider()
            chatInputBarView
        }
        .padding(DesignSystem.medium)
        .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
        .cornerRadius(DesignSystem.mediumRadius)
    }

    @ViewBuilder
    var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignSystem.medium) {
                    ForEach(chatHistory) { msg in
                        AIChatBubbleView(text: msg.text, isUser: msg.isUser)
                            .id(msg.id)
                    }

                    // 正在流式生成时的临时显示占位符（使用共享 AI 思考中与打字气泡）
                    if labManager.isGenerating {
                        generatingPlaceholderView
                    }
                }
                .padding(.vertical, DesignSystem.small)
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
    private var generatingPlaceholderView: some View {
        HStack {
            if labManager.generatedText.isEmpty {
                AIThinkingBubbleView()
            } else {
                AIChatBubbleView(text: labManager.generatedText, isUser: false)
            }
        }
        .id("generating_anchor")
    }

    @ViewBuilder
    var chatInputBarView: some View {
        HStack(alignment: .center, spacing: DesignSystem.medium) {
            // 左侧特化附件（加号）菜单按钮，根据不同用例由 ModelLabManager 状态层分发不同选项，避开 View 本地化审计
            Menu {
                ForEach(labManager.attachmentOptions) { option in
                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        toastManager.show(type: .success, message: option.successMessage)
                    }) {
                        Label(option.title, systemImage: option.icon)
                    }
                }
            } label: {
                Image(systemName: DesignSystem.Icons.plus)
                    .font(.title2)
                    .foregroundStyle(Color.theme.cyan)
                    .frame(width: DesignSystem.Action.inputBarHeight, height: DesignSystem.Action.inputBarHeight)
            }
            .buttonStyle(.plain)

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
                Image(systemName: labManager.isGenerating ? DesignSystem.Icons.stop : DesignSystem.Icons.send)
                    .font(.title2)
                    .foregroundStyle(labManager.isGenerating ? .red : (!chatInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.theme.cyan : .secondary))
                    .frame(width: DesignSystem.Action.inputBarHeight, height: DesignSystem.Action.inputBarHeight)
            }
            .disabled(chatInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !labManager.isGenerating)
        }
        .padding(.horizontal, DesignSystem.standardPadding)
        .padding(.vertical, DesignSystem.tightPadding)
        .background(labManager.isGenerating ? Color.appCard.opacity(DesignSystem.Opacity.soft) : Color.appCard)
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
            // 调用已有的 runSimulation 模拟回复
            await labManager.runSimulation(for: .aiChat, model: model, prompt: text)

            // 推理结束后，把流式生成的文本转入历史对话消息，并清空生成缓冲区
            let aiMsg = LabChatMessage(isUser: false, text: labManager.generatedText)
            chatHistory.append(aiMsg)
            labManager.generatedText = ""
        }
    }
}

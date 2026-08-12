//
//  ChatComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：AI 对话功能：多轮对话、流式响应、聊天历史管理。
//
import SwiftUI
import UFPCore
import Dependencies

// MARK: - Chat Bubble View
/// 聊天气泡视图
/// 支持用户消息（右侧、渐变背景）与 AI 消息（左侧、卡片背景）的差异化渲染
struct ChatBubbleView: View {
    @Dependency(\.toastService) private var toastManager
    let message: ChatMessage
    let pages: [KnowledgePage]
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State private var referencesExpanded = false
    @State private var messageRating: Int? // 1: thumbs up, 2: thumbs down
    @Binding var selectedTab: AppTab
    
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onRegenerate: (() -> Void)?
    var predictedQuestions: [String] = []
    var onSelectQuestion: ((String) -> Void)?
    
    var body: some View {
        HStack(spacing: Spacing.medium) { // 12
            if isSelectionMode {
                Image(systemName: isSelected ? DesignSystem.Icons.checkCircle : DesignSystem.Icons.emptyCircle)
                    .foregroundStyle(isSelected ? Color.appAccent : Color.appSecondary)
                    .font(.title3)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            Group {
                switch message.role {
                case .user:
                    userBubble
                case .assistant:
                    assistantBubble
                case .system:
                    systemBubble
                }
            }
        }
        .padding(.vertical, DesignSystem.tiny)
    }
    
    private var timestampString: String {
        message.timestamp.formatted(as: Date.AppFormatStyle.slashDetailed)
    }
    
    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: Spacing.tiny) {
            HStack(alignment: .top, spacing: Spacing.tiny) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.standardPadding)
                    .padding(.vertical, Spacing.medium)
                    .background(
                        LinearGradient(
                            colors: [.appAccent, .appAccent.opacity(DesignSystem.Opacity.pressed)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Domain.AI.Chat.bubbleCornerRadius))
                    .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.subtle), radius: 8, x: 0, y: 4)
                
                Image(systemName: DesignSystem.Icons.personCircle)
                    .font(.title3)
                    .foregroundStyle(.appAccent.opacity(DesignSystem.Opacity.dim))
                    .padding(.top, DesignSystem.tiny)
            }
            
            Text(timestampString)
                .font(.system(size: DesignSystem.caption2FontSize))
                .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
                .padding(.trailing, DesignSystem.small + DesignSystem.tiny + DesignSystem.tiny)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, DesignSystem.Domain.AI.Chat.bubbleTrailingPadding) // 左侧与 trailing 对称避让
        .padding(.trailing, Spacing.standardPadding) // 增加右侧间距，防贴边
    }
    
    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: Spacing.tiny) {
            // Header: Assistant Identity (Outside the bubble)
            HStack(spacing: Spacing.tiny + Spacing.atomic) {
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(DesignSystem.Opacity.glass))
                        .frame(width: DesignSystem.Domain.AI.Chat.avatarSize, height: DesignSystem.Domain.AI.Chat.avatarSize)
                    Image(systemName: DesignSystem.Icons.sparkles)
                        .font(.system(size: DesignSystem.microFontSize, weight: .bold))
                        .foregroundStyle(.appAccent)
                }
                Text(L10n.Chat.aiAssistantName)
                    .font(.system(size: DesignSystem.captionFontSize, weight: .bold))
                    .foregroundStyle(.appAccent)
                
                Spacer()
                
                Text(timestampString)
                    .font(.system(size: DesignSystem.caption2FontSize))
                    .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
            }
            .padding(.horizontal, Spacing.tiny)
            .padding(.bottom, DesignSystem.atomic)
            
            // 气泡最大宽度通过 AppScreen 统一封装，屏蔽 UIScreen/WKInterfaceDevice 平台差异
            let bubbleMaxWidth = AppScreen.bubbleMaxWidth
            
            // Content Bubble
            ChatContentView(text: message.content, pages: pages, selectedTab: $selectedTab)
                .appContainer(padding: true)
                .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
            
            // Collapsible References Panel
            if !message.relatedPageIDs.isEmpty {
                referencesPanel
                    .frame(maxWidth: AppScreen.bubbleMaxWidth, alignment: .leading)
                    .padding(.top, DesignSystem.tiny)
            }
            
            // 延伸探讨与追问推荐卡片 (渲染与 GPT 体验一致的嵌套卡片)
            if !predictedQuestions.isEmpty {
                SuggestedFollowUpCardView(questions: predictedQuestions) { question in
                    onSelectQuestion?(question)
                }
                .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
                .padding(.top, DesignSystem.tiny)
            }
            
            // 操作按钮栏：点赞、贬低、复制、重新生成
            HStack(spacing: DesignSystem.medium) {
                // 点赞按钮
                Button(action: {
                    HapticFeedback.shared.trigger(.selection)
                    messageRating = messageRating == 1 ? nil : 1
                }) {
                    Image(systemName: messageRating == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.caption)
                        .foregroundStyle(messageRating == 1 ? Color.theme.blue : .appSecondary)
                }
                .buttonStyle(.plain)
                
                // 贬低按钮
                Button(action: {
                    HapticFeedback.shared.trigger(.selection)
                    messageRating = messageRating == 2 ? nil : 2
                }) {
                    Image(systemName: messageRating == 2 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.caption)
                        .foregroundStyle(messageRating == 2 ? Color.theme.red : .appSecondary)
                }
                .buttonStyle(.plain)
                
                // 复制按钮
                Button(action: {
                    HapticFeedback.shared.trigger(.selection)
                    let processed = ThinkingProcessor.process(message.content)
                    AppPasteboard.string = processed.mainContent
                    toastManager.show(type: .success, message: L10n.Chat.copied)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                }
                .buttonStyle(.plain)
                
                // 一键重新生成 (Regenerate)
                if let onRegenerate = onRegenerate {
                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        onRegenerate()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: DesignSystem.Icons.arrowClockwise)
                                .font(.caption2)
                            Text(L10n.Chat.regenerate)
                                .font(.system(size: DesignSystem.captionFontSize, weight: .medium))
                        }
                        .padding(.horizontal, DesignSystem.small)
                        .padding(.vertical, DesignSystem.tiny)
                        .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                        .foregroundStyle(.appAccent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, DesignSystem.tiny)
            .padding(.leading, Spacing.tiny)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Spacing.standardPadding)
        .padding(.trailing, DesignSystem.Domain.AI.Chat.bubbleTrailingPadding)
    }
    
    /// Collapsible references panel showing cited knowledge pages grouped by type
    private var referencesPanel: some View {
        VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
            // Header with expand/collapse toggle
            Button(action: { withAnimation { referencesExpanded.toggle() } }) {
                HStack(spacing: DesignSystem.tightPadding) {
                    Image(systemName: referencesExpanded ? DesignSystem.Icons.chevronDown : DesignSystem.Icons.chevronRight)
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                    Text(referencesExpanded ? L10n.Chat.referencesExpanded : L10n.Chat.referencesCollapsed)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.appSecondary)
                    Spacer()
                    Text("\(message.relatedPageIDs.count)")
                        .font(.caption2)
                        .foregroundStyle(.appAccent)
                        .padding(.horizontal, DesignSystem.small)
                        .padding(.vertical, DesignSystem.atomic)
                        .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                        .clipShape(Capsule())
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("references-toggle")
            
            // Expanded references grouped by page type
            if referencesExpanded {
                let grouped = Dictionary(grouping: message.relatedPageIDs.compactMap { id in pages.first { $0.id == id } }) { $0.pageType }
                // 遍历用户可见的页面类型，过滤掉内部 raw 类型
                ForEach(PageType.allVisibleCases.filter { grouped[$0] != nil }, id: \.self) { type in
                    if let pagesOfType = grouped[type], !pagesOfType.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                            // Type header
                            HStack(spacing: DesignSystem.tiny) {
                                Image(systemName: type.icon)
                                    .font(.caption2)
                                Text(type.displayName)
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(Color.fromModelColorName(type.colorName))
                            .padding(.top, DesignSystem.tiny)
                            
                            // Page chips
                            FlowLayout(spacing: DesignSystem.tightPadding) {
                                ForEach(pagesOfType, id: \.id) { page in
                                    Button(action: { 
                                        selectedTab = .knowledge
                                        router.navigateToPage(id: page.id)
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: page.displayIcon)
                                                .font(.caption2)
                                            Text(page.title)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, DesignSystem.small)
                                        .padding(.vertical, DesignSystem.tiny)
                                        .background(Color.fromModelColorName(type.colorName).opacity(DesignSystem.Opacity.glass))
                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Domain.AI.Chat.referencePanelCornerRadius))
                                        .foregroundStyle(Color.fromModelColorName(type.colorName))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.medium)
        .background(Color.appCard.opacity(DesignSystem.surfaceOpacity))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                .stroke(Color.appBorder.opacity(DesignSystem.softOpacity), lineWidth: DesignSystem.borderWidth)
        )
    }
    
    private var systemBubble: some View {
        HStack {
            Spacer()
            Text(message.content)
                .font(.system(size: Typography.microFontSize + Spacing.atomic)) // 11
                .foregroundStyle(.appSecondary.opacity(Colors.secondaryOpacity)) // 0.8
                .padding(.horizontal, Spacing.wide) // 20
                .padding(.vertical, Spacing.tiny) // 4
                .background(Capsule().fill(Color.appCard.opacity(DesignSystem.Opacity.soft))) // 0.5
            Spacer()
        }
        .padding(.vertical, Spacing.tightPadding) // 8
    }
}

// MARK: - Chat Content View (renders knowledge links as tappable)
/// 聊天消息内容渲染引擎
/// 负责 Markdown 文本的解析、知识库链接 的交互化处理及超长文本的折叠逻辑
struct ChatContentView: View {
    let text: String
    let pages: [KnowledgePage]
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State private var isThinkingExpanded = false
    @Binding var selectedTab: AppTab
    
    var body: some View {
        let processed = ThinkingProcessor.process(text)
        
        VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
            // 🛡️ AI 思考过程：从正文中剥离并展示为默认折叠的交互卡片
            if let thinking = processed.thinkingContent {
                VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        withAnimation(DesignSystem.standardAnimation) {
                            isThinkingExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: DesignSystem.tiny) {
                            Image(systemName: DesignSystem.Icons.sparkles)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.appAccent)
                            Text(L10n.Common.aiThinking)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.appSecondary)
                            Spacer()
                            Image(systemName: isThinkingExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.appSecondary)
                        }
                        .padding(.horizontal, DesignSystem.small)
                        .padding(.vertical, DesignSystem.tightPadding)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                                .fill(Color.appAccent.opacity(DesignSystem.secondaryOpacity * 0.5))
                        )
                    }
                    .buttonStyle(.plain)
                    
                    if isThinkingExpanded {
                        Text(thinking)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                            .padding(.leading, DesignSystem.small)
                            .padding(.vertical, DesignSystem.tiny)
                            .overlay(
                                Rectangle()
                                    .fill(Color.appAccent.opacity(DesignSystem.secondaryOpacity))
                                    .frame(width: DesignSystem.atomic),
                                alignment: .leading
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.bottom, DesignSystem.tiny)
            }
            
            // 清理常见的 LLM 转义符错误 (确保 Markdown 渲染正常)
            let cleanedText = processed.mainContent.replacingOccurrences(of: "\\`", with: "`")
                .replacingOccurrences(of: "\\*", with: "*")
                .replacingOccurrences(of: "\\_", with: "_")
                .replacingOccurrences(of: "\\[\\[", with: "[[")
                .replacingOccurrences(of: "\\]\\]", with: "]]")
            
            MarkdownRendererView(content: cleanedText, isPrivate: false, onLinkTap: { title in
                let targetTitle = title.trimmingCharacters(in: .whitespaces)
                if let page = pages.first(where: { $0.title.localizedCaseInsensitiveCompare(targetTitle) == .orderedSame }) {
                    HapticFeedback.shared.trigger(.link)
                    selectedTab = .knowledge
                    router.navigateToPage(id: page.id)
                }
            }, isCompact: true)
        }
    }
}

// MARK: - Suggested Follow-up Card View
/// 延伸探讨与追问推荐卡片 (匹配高端 GPT/Claude 问答下方的卡片样式)
struct SuggestedFollowUpCardView: View {
    let questions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            // Header
            HStack(spacing: DesignSystem.tiny) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.appAccent)
                Text(L10n.AI.Prompt.followUpHeader)
                    .font(.system(size: DesignSystem.captionFontSize, weight: .semibold))
                    .foregroundStyle(.appText)
            }

            // Numbered List Items
            VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
                ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        onSelect(question)
                    }) {
                        HStack(alignment: .top, spacing: DesignSystem.small) {
                            Text("\(index + 1).")
                                .font(.system(size: DesignSystem.bodyFontSize, weight: .bold))
                                .foregroundStyle(.appAccent)

                            Text(question)
                                .font(.system(size: DesignSystem.bodyFontSize, weight: .medium))
                                .foregroundStyle(.appText)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
                        }
                        .padding(.horizontal, DesignSystem.medium)
                        .padding(.vertical, DesignSystem.small)
                        .background(Color.appCard.opacity(DesignSystem.Opacity.subtle))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                                .stroke(Color.appBorder.opacity(DesignSystem.Opacity.subtle), lineWidth: DesignSystem.borderWidth)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DesignSystem.standardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                .fill(Color.appCard.opacity(DesignSystem.Opacity.glass))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                .stroke(Color.appBorder.opacity(DesignSystem.Opacity.subtle), lineWidth: DesignSystem.borderWidth)
        )
        .shadow(color: Color.appBackground.opacity(DesignSystem.shadowOpacity), radius: 6, x: 0, y: 2)
    }
}

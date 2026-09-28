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
import UFPDesignSystem

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
        HStack(spacing: DesignTokens.Spacing.medium) { // 12
            if isSelectionMode {
                Image(systemName: isSelected ? DesignTokens.Icons.checkCircle : DesignTokens.Icons.emptyCircle)
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
        .padding(.vertical, DesignTokens.Spacing.tiny)
    }
    
    private var timestampString: String {
        message.timestamp.formatted(as: Date.AppFormatStyle.slashDetailed)
    }
    
    /// 时间戳标签（消除 userBubble 与 assistantBubble 内重复的时间戳样式链）
    private var timestampLabel: some View {
        Text(timestampString)
            .font(.system(size: DesignTokens.Typography.caption2FontSize))
            .foregroundStyle(.appSecondary.opacity(DesignTokens.Opacity.dim))
    }
    
    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.tiny) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.tiny) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.Spacing.standardPadding)
                    .padding(.vertical, DesignTokens.Spacing.medium)
                    .background(
                        LinearGradient(
                            colors: [.appAccent, .appAccent.opacity(DesignTokens.Opacity.pressed)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Domain.AI.Chat.bubbleCornerRadius))
                    .shadow(color: Color.appAccent.opacity(DesignTokens.Opacity.subtle), radius: 8, x: 0, y: 4)
                
                Image(systemName: DesignTokens.Icons.personCircle)
                    .font(.title3)
                    .foregroundStyle(.appAccent.opacity(DesignTokens.Opacity.dim))
                    .padding(.top, DesignTokens.Spacing.tiny)
            }
            
            timestampLabel
                .padding(.trailing, DesignTokens.SystemSpacing.content)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, DesignSystem.Domain.AI.Chat.bubbleTrailingPadding) // 左侧与 trailing 对称避让
        .padding(.trailing, DesignTokens.Spacing.standardPadding) // 增加右侧间距，防贴边
    }
    
    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
            // Header: Assistant Identity (Outside the bubble)
            HStack(spacing: DesignTokens.Spacing.tiny + DesignTokens.Spacing.atomic) {
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(DesignTokens.Opacity.glass))
                        .frame(width: DesignSystem.Domain.AI.Chat.avatarSize, height: DesignSystem.Domain.AI.Chat.avatarSize)
                    Image(systemName: DesignTokens.Icons.sparkles)
                        .font(.system(size: DesignTokens.Typography.microFontSize, weight: .bold))
                        .foregroundStyle(.appAccent)
                }
                Text(L10n.Chat.aiAssistantName)
                    .font(.system(size: DesignTokens.Typography.captionFontSize, weight: .bold))
                    .foregroundStyle(.appAccent)
                
                Spacer()
                
                timestampLabel
            }
            .padding(.horizontal, DesignTokens.Spacing.tiny)
            .padding(.bottom, DesignTokens.Spacing.atomic)
            
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
                    .padding(.top, DesignTokens.Spacing.tiny)
            }
            
            // 延伸探讨与追问推荐卡片 (渲染与 GPT 体验一致的嵌套卡片)
            if !predictedQuestions.isEmpty {
                SuggestedFollowUpCardView(questions: predictedQuestions) { question in
                    onSelectQuestion?(question)
                }
                .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
                .padding(.top, DesignTokens.Spacing.tiny)
            }
            
            // 操作按钮栏：点赞、贬低、复制、重新生成
            HStack(spacing: DesignTokens.Spacing.medium) {
                // 点赞按钮
                ratingButton(ratingValue: 1,
                             activeIcon: FeatureConstants.ChatRatingIcon.thumbsupFill,
                             inactiveIcon: FeatureConstants.ChatRatingIcon.thumbsup,
                             activeColor: Color.theme.blue)
                
                // 贬低按钮
                ratingButton(ratingValue: 2,
                             activeIcon: FeatureConstants.ChatRatingIcon.thumbsdownFill,
                             inactiveIcon: FeatureConstants.ChatRatingIcon.thumbsdown,
                             activeColor: Color.theme.red)
                
                // 复制按钮
                Button(action: {
                    HapticFeedback.shared.trigger(.selection)
                    let processed = ThinkingProcessor.process(message.content)
                    AppPasteboard.string = processed.mainContent
                    toastManager.show(type: .success, message: L10n.Chat.copied)
                }) {
                    Image(systemName: DesignTokens.Icons.copy)
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
                        HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                            Image(systemName: DesignTokens.Icons.arrowClockwise)
                                .font(.caption2)
                            Text(L10n.Chat.regenerate)
                                .font(.system(size: DesignTokens.Typography.captionFontSize, weight: .medium))
                        }
                        .commonContentPadding(horizontal: DesignTokens.Spacing.small, vertical: DesignTokens.Spacing.tiny)
                        .background(Color.appAccent.opacity(DesignTokens.Opacity.subtle))
                        .foregroundStyle(.appAccent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, DesignTokens.Spacing.tiny)
            .padding(.leading, DesignTokens.Spacing.tiny)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, DesignTokens.Spacing.standardPadding)
        .padding(.trailing, DesignSystem.Domain.AI.Chat.bubbleTrailingPadding)
    }

    /// 评分按钮（点赞/贬低共用，消除重复的 Button+Image+foregroundStyle 链）
    private func ratingButton(ratingValue: Int, activeIcon: String, inactiveIcon: String, activeColor: Color) -> some View {
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            messageRating = messageRating == ratingValue ? nil : ratingValue
        }) {
            Image(systemName: messageRating == ratingValue ? activeIcon : inactiveIcon)
                .font(.caption)
                .foregroundStyle(messageRating == ratingValue ? activeColor : .appSecondary)
        }
        .buttonStyle(.plain)
    }
    
    /// Collapsible references panel showing cited knowledge pages grouped by type
    private var referencesPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tightPadding) {
            // Header with expand/collapse toggle
            Button(action: { withAnimation { referencesExpanded.toggle() } }) {
                HStack(spacing: DesignTokens.Spacing.tightPadding) {
                    Image(systemName: referencesExpanded ? DesignTokens.Icons.chevronDown : DesignTokens.Icons.chevronRight)
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                    Text(referencesExpanded ? L10n.Chat.referencesExpanded : L10n.Chat.referencesCollapsed)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.appSecondary)
                    Spacer()
                    AppSubtlePill(text: "\(message.relatedPageIDs.count)")
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
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                            // Type header
                            HStack(spacing: DesignTokens.Spacing.tiny) {
                                Image(systemName: type.icon)
                                    .font(.caption2)
                                Text(type.displayName)
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(Color.fromModelColorName(type.colorName))
                            .padding(.top, DesignTokens.Spacing.tiny)
                            
                            // Page chips
                            FlowLayout(spacing: DesignTokens.Spacing.tightPadding) {
                                ForEach(pagesOfType, id: \.id) { page in
                                    Button(action: { 
                                        selectedTab = .knowledge
                                        router.navigateToPage(id: page.id)
                                    }) {
                                        HStack(spacing: DesignTokens.SystemSpacing.tight) {
                                            Image(systemName: page.displayIcon)
                                                .font(.caption2)
                                            Text(page.title)
                                                .font(.caption)
                                        }
                                        .commonContentPadding(horizontal: DesignTokens.Spacing.small, vertical: DesignTokens.Spacing.tiny)
                                        .background(Color.fromModelColorName(type.colorName).opacity(DesignTokens.Opacity.glass))
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
        .padding(DesignTokens.Spacing.medium)
        .chatSmallCardStyle(backgroundOpacity: DesignTokens.Colors.Opacity.surfaceOpacity)
    }
    
    private var systemBubble: some View {
        HStack {
            Spacer()
            Text(message.content)
                .font(.system(size: DesignTokens.Typography.microFontSize + DesignTokens.Spacing.atomic)) // 11
                .foregroundStyle(.appSecondary.opacity(DesignTokens.Colors.secondaryOpacity)) // 0.8
                .padding(.horizontal, DesignTokens.Spacing.wide) // 20
                .padding(.vertical, DesignTokens.Spacing.tiny) // 4
                .background(Capsule().fill(Color.appCard.opacity(DesignTokens.Opacity.soft))) // 0.5
            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.tightPadding) // 8
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
        
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tightPadding) {
            // 🛡️ AI 思考过程：从正文中剥离并展示为默认折叠的交互卡片
            if let thinking = processed.thinkingContent {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        withAnimation(DesignTokens.Animations.Interaction.standardAnimation) {
                            isThinkingExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: DesignTokens.Spacing.tiny) {
                            Image(systemName: DesignTokens.Icons.sparkles)
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
                        .padding(.horizontal, DesignTokens.Spacing.small)
                        .padding(.vertical, DesignTokens.Spacing.tightPadding)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius)
                                .fill(Color.appAccent.opacity(DesignTokens.SystemOpacity.disabled))
                        )
                    }
                    .buttonStyle(.plain)
                    
                    if isThinkingExpanded {
                        Text(thinking)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                            .padding(.leading, DesignTokens.Spacing.small)
                            .padding(.vertical, DesignTokens.Spacing.tiny)
                            .overlay(
                                Rectangle()
                                    .fill(Color.appAccent.opacity(DesignTokens.Colors.Opacity.secondaryOpacity))
                                    .frame(width: DesignTokens.Spacing.atomic),
                                alignment: .leading
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.bottom, DesignTokens.Spacing.tiny)
            }
            
            // 清理常见的 LLM 转义符错误 (确保 Markdown 渲染正常)
            let cleanedText = ChatContentSanitizer.sanitizeEscapes(processed.mainContent)
            
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            // Header
            HStack(spacing: DesignTokens.Spacing.tiny) {
                Image(systemName: DesignTokens.Icons.sparkles)
                    .font(.caption)
                    .foregroundStyle(.appAccent)
                Text(L10n.AI.Prompt.followUpHeader)
                    .font(.system(size: DesignTokens.Typography.captionFontSize, weight: .semibold))
                    .foregroundStyle(.appText)
            }

            // Numbered List Items
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.tightPadding) {
                ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        onSelect(question)
                    }) {
                        HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
                            Text("\(index + 1).")
                                .font(.system(size: DesignTokens.Typography.bodyFontSize, weight: .bold))
                                .foregroundStyle(.appAccent)

                            Text(question)
                                .font(.system(size: DesignTokens.Typography.bodyFontSize, weight: .medium))
                                .foregroundStyle(.appText)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)

                            Image(systemName: DesignTokens.Icons.chevronRight)
                                .font(.caption2)
                                .foregroundStyle(.appSecondary.opacity(DesignTokens.Opacity.dim))
                        }
                        .padding(.horizontal, DesignTokens.Spacing.medium)
                        .padding(.vertical, DesignTokens.Spacing.small)
                        .chatSmallCardStyle(backgroundOpacity: DesignTokens.Opacity.subtle)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DesignTokens.Spacing.standardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.standardRadius)
                .fill(Color.appCard.opacity(DesignTokens.Opacity.glass))
        )
        .overlayStroke()
        .shadow(color: Color.appBackground.opacity(DesignTokens.Spacing.shadowOpacity), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Chat 组件卡片样式辅助
private extension View {
    /// 小圆角卡片样式：background(appCard) + clipShape(smallRadius) + overlayStroke
    func chatSmallCardStyle(backgroundOpacity: Double) -> some View {
        self
            .background(Color.appCard.opacity(backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius))
            .overlayStroke(cornerRadius: DesignTokens.Spacing.smallRadius)
    }
}

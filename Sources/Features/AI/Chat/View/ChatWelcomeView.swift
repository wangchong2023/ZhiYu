//
//  ChatWelcomeView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 ChatWelcome 界面的 UI 视图层组件。
//
import SwiftUI
import Dependencies
import UFPDesignSystem

struct ChatWelcomeView: View {
    let isSheet: Bool
    @Environment(ChatCoordinator.self) var coordinator
    @Environment(AppStore.self) var store
    @Dependency(\.promptService) private var promptService

    init(isSheet: Bool = false) {
        self.isSheet = isSheet
    }

    var body: some View {
        VStack(spacing: isSheet ? DesignTokens.Spacing.medium : DesignTokens.Spacing.small) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.wide) {
                    // 1. 我的指令 (置顶)
                    SuggestionGroupView(
                        title: L10n.Chat.group.user,
                        icon: DesignTokens.Icons.pinFill,
                        queries: promptService.userShortcuts.map { $0.text }
                    )
                    
                    // 2. AI 启发 (动态生成)
                    if coordinator.isGeneratingAIQuestions {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text(L10n.Chat.ai.thinking).font(.caption).foregroundStyle(.appSecondary)
                        }.padding(.leading)
                    } else if !coordinator.insightfulQuestions.isEmpty {
                        SuggestionGroupView(
                            title: L10n.Chat.group.ai,
                            icon: DesignTokens.Icons.sparkles,
                            queries: coordinator.insightfulQuestions,
                            color: .appAccent
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct SuggestionGroupView: View {
    let title: String
    let icon: String
    let queries: [String]
    var color: Color = .appSecondary
    
    @Environment(ChatCoordinator.self) var coordinator
    @Environment(AppStore.self) var store

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.elementLarge) {
            // 标题现在支持点击直接触发“总体探索”
            Button(action: {
                HapticFeedback.shared.trigger(.link)
                let query = L10n.Chat.deepExplorePrompt(title)
                sendQuery(query)
            }) {
                HStack(spacing: DesignTokens.SystemSpacing.small) {
                    Image(systemName: icon).font(.caption2)
                    Text(title).font(.caption.weight(.bold))
                    Spacer()
                    Image(systemName: DesignTokens.Icons.promptLibrary)
                        .font(.system(size: DesignTokens.Metrics.heroValueSize * FeatureConstants.ChatWelcome.iconFontScale))
                        .opacity(DesignTokens.Opacity.soft)
                }
                .foregroundStyle(color)
                .padding(.leading, DesignTokens.Spacing.tiny)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            ForEach(queries, id: \.self) { query in
                Button(action: { 
                    HapticFeedback.shared.trigger(.link)
                    coordinator.showPrompts = false
                    sendQuery(query)
                }) {
                    HStack {
                        Text(query).font(.subheadline).foregroundStyle(.appText).multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: DesignTokens.Icons.arrowUpRight).font(.caption2).foregroundStyle(.appAccent.opacity(DesignTokens.Opacity.overlay))
                    }
                    .padding()
                    .appCardClip(cornerRadius: DesignTokens.Spacing.standardRadius)
                    .overlayStroke(borderColor: Color.appBorder.opacity(DesignTokens.Colors.Opacity.disabledOpacity))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 发送追问查询（消除重复的 Task + coordinator.sendMessage 链）
    private func sendQuery(_ query: String) {
        Task { await coordinator.sendMessage(query: query, pages: store.pages) }
    }
}

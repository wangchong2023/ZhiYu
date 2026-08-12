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

struct ChatWelcomeView: View {
    let isSheet: Bool
    @Environment(ChatCoordinator.self) var coordinator
    @Environment(AppStore.self) var store
    @Dependency(\.promptService) private var promptService

    init(isSheet: Bool = false) {
        self.isSheet = isSheet
    }

    var body: some View {
        VStack(spacing: isSheet ? DesignSystem.medium : DesignSystem.small) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.wide) {
                    // 1. 我的指令 (置顶)
                    SuggestionGroupView(
                        title: L10n.Chat.group.user,
                        icon: DesignSystem.Icons.pinFill,
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
                            icon: DesignSystem.Icons.sparkles,
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
        VStack(alignment: .leading, spacing: DesignSystem.small + DesignSystem.atomic) {
            // 标题现在支持点击直接触发“总体探索”
            Button(action: {
                HapticFeedback.shared.trigger(.link)
                let query = L10n.Chat.deepExplorePrompt(title)
                Task { await coordinator.sendMessage(query: query, pages: store.pages) }
            }) {
                HStack(spacing: DesignSystem.tiny + DesignSystem.atomic) {
                    Image(systemName: icon).font(.caption2)
                    Text(title).font(.caption.weight(.bold))
                    Spacer()
                    Image(systemName: DesignSystem.Icons.promptLibrary)
                        .font(.system(size: DesignSystem.Metrics.heroValueSize * 0.38))
                        .opacity(DesignSystem.Opacity.soft)
                }
                .foregroundStyle(color)
                .padding(.leading, DesignSystem.tiny)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            ForEach(queries, id: \.self) { query in
                Button(action: { 
                    HapticFeedback.shared.trigger(.link)
                    coordinator.showPrompts = false
                    Task { await coordinator.sendMessage(query: query, pages: store.pages) }
                }) {
                    HStack {
                        Text(query).font(.subheadline).foregroundStyle(.appText).multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: DesignSystem.Icons.arrowUpRight).font(.caption2).foregroundStyle(.appAccent.opacity(DesignSystem.Opacity.overlay))
                    }
                    .padding()
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                            .stroke(Color.appBorder.opacity(DesignSystem.disabledOpacity), lineWidth: DesignSystem.borderWidth)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

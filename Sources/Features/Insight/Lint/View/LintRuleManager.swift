//
//  LintRuleManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：AI 治理建议面板 — 重构建议列表 / 潜在链接发现 / 建议操作行。
//

import SwiftUI

// MARK: - AI 建议面板

/// AI 建议内容面板：展示重构建议与潜在链接发现
struct LintAISuggestionsPanel: View {
    let aiStore: AIWorkflowStore

    var body: some View {
        VStack {
            if aiStore.refactorSuggestions.isEmpty && aiStore.potentialLinks.isEmpty {
                emptyAIView
            } else {
                List {
                    if !aiStore.refactorSuggestions.isEmpty {
                        Section(L10n.Lint.refactorSection) {
                            ForEach(aiStore.refactorSuggestions) { suggestion in
                                RefactorSuggestionRow(suggestion: suggestion)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                aiStore.removeRefactorSuggestion(id: suggestion.id)
                                            }
                                        } label: {
                                            Label(L10n.Common.ignore, systemImage: DesignSystem.Icons.privacyMode)
                                        }
                                    }
                            }
                        }
                    }

                    if !aiStore.potentialLinks.isEmpty {
                        Section(L10n.Lint.linkDiscoverySection) {
                            ForEach(aiStore.potentialLinks) { link in
                                PotentialLinkRow(link: link)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                aiStore.removePotentialLink(id: link.id)
                                            }
                                        } label: {
                                            Label(L10n.Common.ignore, systemImage: DesignSystem.Icons.privacyMode)
                                        }
                                    }
                            }
                        }
                    }
                }
                .adaptiveListStyle()
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var emptyAIView: some View {
        VStack(spacing: DesignSystem.standardPadding) {
            Spacer()
            Image(systemName: DesignSystem.Icons.sparkles)
                .font(.system(size: DesignSystem.Domain.Lint.emptyIconSize))
                .foregroundStyle(.appAccent)
            Text(L10n.Lint.noAISuggestions)
                .font(.title3.weight(.semibold))
            Text(L10n.Lint.noAISuggestionsHint)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }
}

// MARK: - AI 建议行组件

struct RefactorSuggestionRow: View {
    let suggestion: RefactorSuggestion
    @Environment(AppStore.self) var store

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            HStack {
                Label(suggestion.type.uppercased(), systemImage: iconName)
                    .font(.caption2.bold())
                    .padding(.horizontal, DesignSystem.tightPadding)
                    .padding(.vertical, DesignSystem.atomic)
                    .background(color.opacity(DesignSystem.Opacity.medium))
                    .foregroundStyle(color)
                    .clipShape(Capsule())

                Text(suggestion.target)
                    .font(.subheadline.bold())

                Spacer()

                AppBorderedButton(title: L10n.Lint.apply, color: .appAccent, maxWidth: 80) {
                    Task { await store.applyRefactorSuggestion(suggestion) }
                }
            }

            Text(suggestion.reason)
                .font(.caption)
                .foregroundStyle(.appSecondary)

            Text(L10n.Lint.aiFixSuggestion(suggestion.suggestion))
                .font(.caption2)
                .padding(DesignSystem.tightPadding)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.microRadius))
        }
        .padding(.vertical, DesignSystem.tiny)
    }

    private var iconName: String {
        switch suggestion.type {
        case FeatureConstants.LintAction.merge: return DesignSystem.Icons.merge
        case FeatureConstants.LintAction.split: return DesignSystem.Icons.branch
        case FeatureConstants.LintAction.rename: return DesignSystem.Icons.cursorIbeam
        default: return DesignSystem.Icons.sparkles
        }
    }

    private var color: Color {
        switch suggestion.type {
        case FeatureConstants.LintAction.merge: return Color.theme.orange
        case FeatureConstants.LintAction.split: return Color.theme.purple
        case FeatureConstants.LintAction.rename: return Color.theme.blue
        default: return .appAccent
        }
    }
}

struct PotentialLinkRow: View {
    let link: PotentialLinkSuggestion
    @Environment(AppStore.self) var store

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                Text(link.sourceTitle)
                    .font(.subheadline.bold())
                HStack(spacing: DesignSystem.tiny) {
                    Image(systemName: DesignSystem.Icons.forward)
                        .font(.caption2)
                    Text("[[\(link.targetTitle)]]")
                        .font(.caption)
                        .foregroundStyle(.appAccent)
                }
            }

            Spacer()

            AppBorderedButton(title: L10n.Lint.apply, color: .appAccent, maxWidth: 80) {
                Task { await store.applyPotentialLink(link) }
            }
        }
        .padding(.vertical, DesignSystem.tiny)
    }
}

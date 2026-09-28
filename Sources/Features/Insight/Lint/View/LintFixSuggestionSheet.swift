//
//  LintFixSuggestionSheet.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：质量问题行渲染与 AI 修复建议交互 — 问题详情 / 页面跳转 / AI 修复建议拉取。
//

import SwiftUI
import UFPDesignSystem

// MARK: - 质量问题行渲染

/// 单个知识质量问题的展示行组件
/// 负责展示特定质量问题的详情、修复建议，并提供 AI 深度分析入口及页面快捷跳转能力
struct LintIssueRow: View {
    let issue: LintIssue
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State private var aiSuggestion: String?
    @State private var isAnalyzing = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tightPadding) {
            HStack(spacing: DesignTokens.Spacing.small) {
                Image(systemName: issue.type.icon)
                    .foregroundStyle(Color.fromModelColorName(issue.severity.colorName))
                    .frame(width: DesignTokens.IconSize.micro, height: DesignTokens.IconSize.micro)

                Text(issue.message)
                    .font(.subheadline)
                    .foregroundStyle(.appText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !issue.suggestion.isEmpty {
                HStack(spacing: DesignTokens.Spacing.tiny) {
                    Image(systemName: DesignTokens.Icons.concept)
                        .font(.caption2)
                        .foregroundStyle(Color.theme.yellow)
                    Text(issue.suggestion)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                }
                .padding(.leading, DesignTokens.Spacing.giant)
            }

            if let pageID = issue.pageID,
               store.pages.contains(where: { $0.id == pageID }) {
                HStack(spacing: DesignTokens.Spacing.medium) {
                    Button(action: { router.navigateToPage(id: pageID) }) {
                        Text(L10n.Lint.goToPage)
                            .font(.caption2)
                            .foregroundStyle(.appAccent)
                    }

                    if store.llmService.isEnabled {
                        Button(action: fetchAISuggestion) {
                            HStack(spacing: DesignTokens.Spacing.tiny) {
                                if isAnalyzing {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Image(systemName: DesignTokens.Icons.sparkles)
                                        .font(.caption2)
                                }
                                Text(L10n.Lint.aiFixSuggestionShort)
                                    .font(.caption2)
                            }
                            .foregroundStyle(Color.theme.purple)
                        }
                        .disabled(isAnalyzing)
                    }
                }
                .padding(.leading, DesignTokens.Spacing.giant)
            }

            if let suggestion = aiSuggestion {
                Text(suggestion)
                    .font(.caption)
                    .padding(DesignTokens.Spacing.small)
                    .background(Color.theme.purple.opacity(DesignTokens.Opacity.subtle))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius)
                            .stroke(Color.theme.purple.opacity(DesignTokens.Opacity.medium), lineWidth: DesignTokens.SystemStroke.divider)
                    )
                    .padding(.leading, DesignTokens.Spacing.giant)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, DesignTokens.Spacing.tiny)
    }

    private func fetchAISuggestion() {
        guard !isAnalyzing else { return }
        isAnalyzing = true

        Task {
            do {
                let suggestion = try await store.aiWorkflowStore.fetchFixSuggestion(for: issue)
                await MainActor.run {
                    withAnimation {
                        self.aiSuggestion = suggestion
                        self.isAnalyzing = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.aiSuggestion = L10n.Lint.aiSuggestionError(error.localizedDescription)
                    self.isAnalyzing = false
                }
            }
        }
    }
}

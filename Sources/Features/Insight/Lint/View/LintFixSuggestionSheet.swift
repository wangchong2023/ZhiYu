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
        VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
            HStack(spacing: DesignSystem.small) {
                Image(systemName: issue.type.icon)
                    .foregroundStyle(Color.fromModelColorName(issue.severity.colorName))
                    .frame(width: DesignSystem.IconSize.micro, height: DesignSystem.IconSize.micro)

                Text(issue.message)
                    .font(.subheadline)
                    .foregroundStyle(.appText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !issue.suggestion.isEmpty {
                HStack(spacing: DesignSystem.tiny) {
                    Image(systemName: DesignSystem.Icons.concept)
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(issue.suggestion)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                }
                .padding(.leading, DesignSystem.giant)
            }

            if let pageID = issue.pageID,
               store.pages.contains(where: { $0.id == pageID }) {
                HStack(spacing: DesignSystem.medium) {
                    Button(action: { router.navigateToPage(id: pageID) }) {
                        Text(L10n.Lint.goToPage)
                            .font(.caption2)
                            .foregroundStyle(.appAccent)
                    }

                    if store.llmService.isEnabled {
                        Button(action: fetchAISuggestion) {
                            HStack(spacing: DesignSystem.tiny) {
                                if isAnalyzing {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Image(systemName: DesignSystem.Icons.sparkles)
                                        .font(.caption2)
                                }
                                Text(L10n.Lint.aiFixSuggestionShort)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.purple)
                        }
                        .disabled(isAnalyzing)
                    }
                }
                .padding(.leading, DesignSystem.giant)
            }

            if let suggestion = aiSuggestion {
                Text(suggestion)
                    .font(.caption)
                    .padding(DesignSystem.small)
                    .background(Color.theme.purple.opacity(DesignSystem.Opacity.subtle))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                            .stroke(Color.theme.purple.opacity(DesignSystem.Opacity.medium), lineWidth: 1)
                    )
                    .padding(.leading, DesignSystem.giant)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, DesignSystem.tiny)
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

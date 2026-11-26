//
//  PageDetailAIMenuButton.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：跨平台页面详情 AI 菜单按钮 —— watchOS 使用简单 Button，其他平台使用嵌套 Menu。
//

import SwiftUI
import UFPDesignSystem

/// 页面详情 AI 操作菜单按钮
///
/// watchOS 上展示为单一 AI 摘要生成按钮；
/// iOS / macOS 上展示为完整嵌套 Menu（含摘要、行动提取、合成实验室、历史等）。
public struct PageDetailAIMenuButton: View {
    let isDisabled: Bool
    let onGenerateSummary: () -> Void
    let onExtractActions: () -> Void
    let onMindmap: () -> Void
    let onQuiz: () -> Void
    let onSlides: () -> Void
    let onReport: () -> Void
    let onInfographic: () -> Void
    let onShowSnapshotHistory: () -> Void
    let onExpandContent: () -> Void
    let onFindRelatedLinks: () -> Void

    public init(
        isDisabled: Bool,
        onGenerateSummary: @escaping () -> Void,
        onExtractActions: @escaping () -> Void,
        onMindmap: @escaping () -> Void,
        onQuiz: @escaping () -> Void,
        onSlides: @escaping () -> Void,
        onReport: @escaping () -> Void,
        onInfographic: @escaping () -> Void,
        onShowSnapshotHistory: @escaping () -> Void,
        onExpandContent: @escaping () -> Void,
        onFindRelatedLinks: @escaping () -> Void
    ) {
        self.isDisabled = isDisabled
        self.onGenerateSummary = onGenerateSummary
        self.onExtractActions = onExtractActions
        self.onMindmap = onMindmap
        self.onQuiz = onQuiz
        self.onSlides = onSlides
        self.onReport = onReport
        self.onInfographic = onInfographic
        self.onShowSnapshotHistory = onShowSnapshotHistory
        self.onExpandContent = onExpandContent
        self.onFindRelatedLinks = onFindRelatedLinks
    }

    public var body: some View {
        #if os(watchOS)
        simpleButton
        #else
        fullMenu
        #endif
    }

    // MARK: - watchOS 简化按钮 / iOS & macOS 完整菜单

    #if os(watchOS)
    private var simpleButton: some View {
        Button(action: onGenerateSummary) {
            Image(systemName: DesignTokens.Icons.sparkles)
                .foregroundStyle(.appAccent)
        }
        .disabled(isDisabled)
    }
    #else
    private var fullMenu: some View {
        Menu {
            Group {
                Button(L10n.Knowledge.Page.AI.summary, systemImage: DesignTokens.Icons.aiSummary, action: onGenerateSummary)
                Button(L10n.Knowledge.Page.AI.extractActions, systemImage: DesignTokens.Icons.aiExtract, action: onExtractActions)

                Menu {
                    Group {
                        Button(L10n.Knowledge.Page.AI.mindmap, systemImage: DesignTokens.Icons.mindmap, action: onMindmap)
                        Button(L10n.Knowledge.Page.AI.quiz, systemImage: DesignTokens.Icons.quiz, action: onQuiz)
                        Button(L10n.Knowledge.Page.AI.slides, systemImage: DesignTokens.Icons.slides, action: onSlides)
                        Button(L10n.Knowledge.Page.AI.report, systemImage: DesignTokens.Icons.report, action: onReport)
                        Button(L10n.Knowledge.Page.AI.infographic, systemImage: DesignTokens.Icons.infographic, action: onInfographic)
                    }
                    .labelStyle(.titleAndIcon)
                } label: {
                    Label(L10n.Knowledge.Page.AI.lab, systemImage: DesignTokens.Icons.lab)
                }

                Divider()
                Button(L10n.Knowledge.Page.History.title, systemImage: DesignTokens.Icons.history, action: onShowSnapshotHistory)
                Button(L10n.Knowledge.Page.expandStub, systemImage: DesignTokens.Icons.expandStub, action: onExpandContent)
                Button(L10n.Knowledge.Page.findLinks, systemImage: DesignTokens.Icons.findLinks, action: onFindRelatedLinks)
            }
            .labelStyle(.titleAndIcon)
        } label: {
            Image(systemName: DesignTokens.Icons.sparkles)
                .foregroundStyle(.appAccent)
                .appToolbarItemStandardFrame()
        }
        .appToolbarButtonStyle()
        .disabled(isDisabled)
    }
    #endif
}

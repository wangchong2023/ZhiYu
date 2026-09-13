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

    // MARK: - watchOS: 简化按钮

    #if os(watchOS)
    private var simpleButton: some View {
        Button(action: onGenerateSummary) {
            Image(systemName: DesignSystem.Icons.sparkles)
                .foregroundStyle(.appAccent)
        }
        .disabled(isDisabled)
    }
    #endif

    // MARK: - iOS / macOS: 完整菜单

    #if !os(watchOS)
    private var fullMenu: some View {
        Menu {
            Button(action: onGenerateSummary) {
                Label(L10n.Knowledge.Page.AI.summary, systemImage: DesignSystem.Icons.aiSummary)
            }
            Button(action: onExtractActions) {
                Label(L10n.Knowledge.Page.AI.extractActions, systemImage: DesignSystem.Icons.aiExtract)
            }

            Menu {
                Button(action: onMindmap) {
                    Label(L10n.Knowledge.Page.AI.mindmap, systemImage: DesignSystem.Icons.mindmap)
                }
                Button(action: onQuiz) {
                    Label(L10n.Knowledge.Page.AI.quiz, systemImage: DesignSystem.Icons.quiz)
                }
                Button(action: onSlides) {
                    Label(L10n.Knowledge.Page.AI.slides, systemImage: DesignSystem.Icons.slides)
                }
                Button(action: onReport) {
                    Label(L10n.Knowledge.Page.AI.report, systemImage: DesignSystem.Icons.report)
                }
                Button(action: onInfographic) {
                    Label(L10n.Knowledge.Page.AI.infographic, systemImage: DesignSystem.Icons.infographic)
                }
            } label: {
                Label(L10n.Knowledge.Page.AI.lab, systemImage: DesignSystem.Icons.lab)
            }

            Divider()
            Button(action: onShowSnapshotHistory) {
                Label(L10n.Knowledge.Page.History.title, systemImage: DesignSystem.Icons.history)
            }
            Button(action: onExpandContent) {
                Label(L10n.Knowledge.Page.expandStub, systemImage: DesignSystem.Icons.expandStub)
            }
            Button(action: onFindRelatedLinks) {
                Label(L10n.Knowledge.Page.findLinks, systemImage: DesignSystem.Icons.findLinks)
            }
        } label: {
            Image(systemName: DesignSystem.Icons.sparkles)
                .foregroundStyle(.appAccent)
        }
        .disabled(isDisabled)
    }
    #endif
}

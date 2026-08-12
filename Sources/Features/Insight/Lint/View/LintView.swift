//
//  LintView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：知识治理中心容器视图 — 组合健康检查 / AI 建议 / 修复建议三个子面板。
//

import SwiftUI
import Dependencies

// MARK: - 治理中心入口

/// 知识治理中心主视图容器
/// 负责为健康检查与 AI 建议提供独立的导航上下文，管理顶层治理生命周期
struct LintView: View {
    @Binding var selection: SidebarSelection?
    var body: some View {
        LintViewContent(selection: $selection)
    }
}

// MARK: - 治理中心核心

/// 知识治理核心内容视图
/// 负责健康得分看板（Dashboard）渲染、结构化问题分析、AI 治理建议展示及自动化修复逻辑
struct LintViewContent: View {
    @Dependency(\.toastService) private var toastManager
    @Binding var selection: SidebarSelection?
    @Environment(AppStore.self) var store
    @Environment(AIWorkflowStore.self) var aiStore
    @Environment(Router.self) var router
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var isRunning = false
    @State private var selectedTab = 0 // 0: 健康检查, 1: AI 建议

    // MARK: - UI Helpers

    private var healthColor: Color {
        switch aiStore.healthLevel {
        case .excellent: return .green
        case .good: return .appAccent
        case .fair: return .orange
        case .poor: return .red
        }
    }

    private var buttonGradient: Color {
        selectedTab == 0 ? .blue : .purple
    }

    var body: some View {
        ZStack {
            PageBackgroundView(accentColor: themeManager.accentColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 选项卡切换
                Picker("", selection: $selectedTab) {
                    Text(L10n.Lint.title).tag(0)
                    Text(L10n.Lint.aiSuggestions).tag(1)
                }
                .segmentedPickerStyleIfAvailable()
                .padding(.horizontal, DesignSystem.huge)
                .padding(.vertical, DesignSystem.tiny)
                .background(.ultraThinMaterial.opacity(DesignSystem.Opacity.shadow))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
                .padding(.horizontal, DesignSystem.standardPadding)

                // 内容区
                Group {
                    if selectedTab == 0 {
                        LintHealthCheckSection(
                            aiStore: aiStore,
                            healthColor: healthColor,
                            onRun: runLint
                        )
                    } else {
                        LintAISuggestionsPanel(aiStore: aiStore)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .appSubPageToolbar(title: selectedTab == 0 ? L10n.Lint.title : L10n.Lint.aiSuggestions) {
            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                if selectedTab == 0 { runLint() } else { runAIScan() }
            }) {
                HStack(spacing: DesignSystem.tightPadding) {
                    ZStack {
                        ProgressView()
                            .controlSize(.small)
                            .opacity(isRunning || aiStore.isScanningAI ? 1 : 0)

                        Image(systemName: selectedTab == 0 ? DesignSystem.Icons.healthCheck : DesignSystem.Icons.sparkles)
                            .font(.system(size: DesignSystem.subheadlineFontSize))
                            .opacity(isRunning || aiStore.isScanningAI ? 0 : 1)
                    }

                    Text(isRunning || aiStore.isScanningAI ? L10n.Lint.scanning : (selectedTab == 0 ? L10n.Lint.runCheck : L10n.Lint.runAIScan))
                }
                .font(.footnote.bold())
                .foregroundStyle(buttonGradient)
                .padding(.horizontal, DesignSystem.small)
            }
            .buttonStyle(.plain)
            .disabled(isRunning || aiStore.isScanningAI)
        }
    }

    private func runLint() {
        isRunning = true
        Task {
            // 模拟扫描耗时，增加视觉反馈
            try? await Task.sleep(nanoseconds: 800_000_000)
            await aiStore.runLint()
            await MainActor.run {
                isRunning = false
                HapticFeedback.shared.trigger(.success)
                toastManager.show(type: .success, message: L10n.Lint.scanComplete)
            }
        }
    }

    private func runAIScan() {
        guard aiStore.isLLMEnabled else {
            HapticFeedback.shared.trigger(.error)
            toastManager.show(type: .error, message: L10n.Lint.aiDisabledHint)
            return
        }

        Task {
            await aiStore.runAIScan()
            await MainActor.run {
                HapticFeedback.shared.trigger(.success)
                toastManager.show(type: .success, message: L10n.Lint.aiScanComplete)
            }
        }
    }
}

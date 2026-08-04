//
//  DeveloperSettingsView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 DeveloperSettings 界面的 UI 视图层组件。
//
import SwiftUI
import UFPCore

struct DeveloperSettingsView: View {
    @Environment(AppStore.self) var store
    @Environment(KnowledgeStore.self) var knowledgeStore
    @Environment(SettingsStore.self) var settingsStore
    @EnvironmentObject var onboardingService: OnboardingService
    @Environment(\.dismiss) var dismiss
    @State private var showStressTestConfirmation = false
    @State private var stressTestTargetCount = 1000
    @State private var isStressTesting = false
    @State private var stressTestCount: Int?

    var body: some View {
        List {

            // MARK: - 性能测试 (Performance Testing)
            Section {
                // 性能测试卡片：将数量选择与压测按钮整合入单个卡片容器中，优化人机交互效率
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(L10n.Settings.developer.stressTest.count, systemImage: "number.circle")
                            .font(.body)
                        Spacer()
                        // 节点数量展示：动态读取本地化表达
                        Text(L10n.Settings.developer.stressTest.nodes(stressTestTargetCount))
                            .bold()
                            .foregroundStyle(Color.theme.accent)
                    }
                    
                    // 使用 Stepper 作为内联调节器，支持 100 到 10000 范围，步长 100
                    Stepper(value: $stressTestTargetCount, in: 100...10000, step: 100) {
                        Text(L10n.Settings.developer.stressTest.sliderLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .disabled(isStressTesting)
                    
                    Divider()
                    
                    // 下方横跨卡片的一体化压力测试按钮，采用高对比度的蓝色主题，带 gauge.with.needle 仪表盘图标
                    Button(action: { showStressTestConfirmation = true }) {
                        HStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "gauge.with.needle")
                                .font(.headline)
                            Text(L10n.Settings.developer.stressTest.run)
                                .bold()
                            if isStressTesting {
                                ProgressView()
                                    .padding(.leading, 4)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(isStressTesting ? Color.secondary.opacity(DesignSystem.Opacity.disabled) : Color.theme.accent)
                        .foregroundColor(Color.theme.white)
                        .cornerRadius(DesignSystem.cardRadius)
                    }
                    .disabled(isStressTesting)
                    .buttonStyle(.plain) // 避免嵌套点击污染
                }
                .padding(.vertical, 8)
            } header: {
                Text(L10n.Settings.developer.section.performance_test)
            } footer: {
                if let count = stressTestCount {
                    Text(L10n.Settings.developer.stressTest.success(count))
                        .font(.caption)
                        .foregroundStyle(Color.theme.orange)
                }
            }
            .appListRowBackground()

            // MARK: - 质量评估
            Section {
                NavigationLink {
                    RAGEvaluationView()
                } label: {
                    Label(L10n.Dashboard.stats.benchmark, systemImage: "checkmark.shield")
                }

                NavigationLink {
                    PerformanceDashboardView(service: store.performanceService)
                } label: {
                    Label(L10n.Common.Perf.title, systemImage: "chart.bar.xaxis")
                }

                NavigationLink {
                    TaskRoutingRulesView()
                } label: {
                    Label(L10n.ModelManager.Routing.taskRules, systemImage: "network")
                }

            } header: {
                Text(L10n.Dashboard.stats.evaluation)
            }
            .appListRowBackground()

            // MARK: - 引导
            Section {
                Button {
                    onboardingService.hasCompletedOnboarding = false
                    ToastManager.shared.show(type: .success, message: L10n.Settings.developer.resetOnboardingDone)
                } label: {
                    Label(L10n.Settings.developer.showWelcomeBanner, systemImage: "sparkles")
                }

                Button {
                    dismiss()
                    Task {
                        try? await Task.sleep(nanoseconds: 400_000_000)
                        onboardingService.reset()
                    }
                } label: {
                    Label(L10n.Settings.developer.showGuidePage, systemImage: "questionmark.circle")
                }
            } header: {
                Text(L10n.Settings.developer.section.onboarding)
            }
            .appListRowBackground()
        }
            .adaptiveListStyle()
            .scrollContentBackground(.hidden)
            .background(PageBackgroundView(accentColor: .blue))
            .navigationTitle(L10n.Settings.Section.developer)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) {
                        dismiss()
                    }
                    .bold()
                }
            }
            .appToast() // 确保在二级导航页面也能正确渲染 Toast，解决被遮挡问题
            .confirmationDialog(L10n.Settings.developer.stressTest.confirmTitle, isPresented: $showStressTestConfirmation, titleVisibility: .visible) {
                Button(L10n.Settings.developer.stressTest.confirmAction(stressTestTargetCount), role: .destructive) {
                    Task { await runStressTest(count: stressTestTargetCount) }
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Settings.developer.stressTest.confirmMessage)
            }
        }

    private func runStressTest(count targetCount: Int) async {
        await MainActor.run {
            self.stressTestTargetCount = targetCount
            self.isStressTesting = true
        }

        // 确保两个默认演示笔记本存在，不存在则创建
        let vaultService = ServiceContainer.shared.resolve(VaultService.self)
        let demoVaultNames = [L10n.Vault.defaultName, L10n.Vault.researchName]
        for name in demoVaultNames where !vaultService.vaults.contains(where: { $0.name == name }) {
                vaultService.createVault(name: name)
        }

        // 对两个默认笔记本注入压力测试数据
        var totalCount = 0
        for vault in vaultService.vaults where demoVaultNames.contains(vault.name) {
            do {
                try await vaultService.selectVaultAndWait(vault)
                let count = (try? await InitialNotebookGenerator.generateStressTestNotebooks(in: store.pageStore, count: targetCount)) ?? 0
                totalCount += count
            } catch {
                // 数据库切换失败时跳过该笔记本
            }
        }

        await MainActor.run {
            self.stressTestCount = totalCount
            self.isStressTesting = false
            Task {
                await knowledgeStore.refresh()
                AppEventBus.shared.publish(.pagesCleared)            }
        }
    }

}

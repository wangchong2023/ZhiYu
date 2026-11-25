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
import Dependencies
import UFPDesignSystem

struct DeveloperSettingsView: View {
    /// 嵌入 SettingsView 详情栏时为 true：隐藏独立「完成」关闭按钮并复用父级统一背景
    var isEmbedded: Bool = false

    @Dependency(\.toastService) private var toastManager
    @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?
    @Environment(AppStore.self) var store
    @Environment(KnowledgeStore.self) var knowledgeStore
    @Environment(SettingsStore.self) var settingsStore
    @EnvironmentObject var onboardingService: OnboardingService
    @Environment(\.dismiss) var dismiss
    @Environment(\.interfaceIdiom) private var idiom
    @State private var showStressTestConfirmation = false
    @State private var stressTestTargetCount = FeatureConstants.StressTest.defaultTargetCount
    @State private var isStressTesting = false
    @State private var stressTestCount: Int?

    var body: some View {
        Form {

            // MARK: - 性能测试 (Performance Testing)
            Section {
                // 性能测试卡片：将数量选择与压测按钮整合入单个卡片容器中，优化人机交互效率
                VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.medium) {
                    HStack {
                        Label(L10n.Settings.developer.stressTest.count, systemImage: DesignTokens.Icons.numberCircle)
                            .font(.body)
                        Spacer()
                        // 节点数量展示：动态读取本地化表达
                        Text(L10n.Settings.developer.stressTest.nodes(stressTestTargetCount))
                            .bold()
                            .foregroundStyle(Color.theme.accent)
                    }
                    
                    // 使用 Stepper 作为内联调节器，支持 100 到 10000 范围，步长 100
                    Stepper(
                        value: $stressTestTargetCount,
                        in: FeatureConstants.StressTest.minTargetCount...FeatureConstants.StressTest.maxTargetCount,
                        step: FeatureConstants.StressTest.step
                    ) {
                        Text(L10n.Settings.developer.stressTest.sliderLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .disabled(isStressTesting)
                    
                    Divider()
                    
                    // macOS HIG：桌面表单操作按钮右对齐紧凑展示；iOS 保持全宽触控按钮
                    HStack {
                        if idiom == .mac { Spacer() }
                        Button(action: { showStressTestConfirmation = true }) {
                            HStack(spacing: DesignTokens.SystemSpacing.element) {
                                if idiom != .mac { Spacer() }
                                Image(systemName: DesignTokens.Icons.gaugeWithNeedle)
                                    .font(idiom == .mac ? .subheadline.weight(.semibold) : .headline)
                                Text(L10n.Settings.developer.stressTest.run)
                                    .font(idiom == .mac ? .subheadline.weight(.semibold) : .headline)
                                if isStressTesting {
                                    ProgressView()
                                        .controlSize(.small)
                                        .padding(.leading, DesignTokens.SystemSpacing.tiny)
                                }
                                if idiom != .mac { Spacer() }
                            }
                            .padding(.horizontal, DesignTokens.Spacing.standardPadding)
                            .padding(.vertical, DesignTokens.SystemSpacing.element)
                            .frame(maxWidth: idiom == .mac ? nil : .infinity)
                            .background(isStressTesting ? Color.secondary.opacity(DesignTokens.Opacity.disabled) : Color.theme.accent)
                            .foregroundColor(Color.theme.white)
                            .clipShape(RoundedRectangle(cornerRadius: idiom == .mac ? DesignTokens.Spacing.mediumRadius : DesignTokens.SystemRadius.card))
                        }
                        .disabled(isStressTesting)
                        .buttonStyle(.plain) // 避免嵌套点击污染
                    }
                }
                .padding(.vertical, DesignTokens.SystemSpacing.element)
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
                NavigationLink(value: SettingsSubRoute.ragEvaluation) {
                    Label(L10n.Dashboard.stats.benchmark, systemImage: DesignTokens.Icons.checkmarkShield)
                }

                NavigationLink(value: SettingsSubRoute.performanceDashboard) {
                    Label(L10n.Common.Perf.title, systemImage: DesignTokens.Icons.chartBarXaxis)
                }

                NavigationLink(value: SettingsSubRoute.taskRoutingRules) {
                    Label(L10n.ModelManager.Routing.taskRules, systemImage: DesignTokens.Icons.settingsAI)
                }

            } header: {
                Text(L10n.Dashboard.stats.evaluation)
            }
            .appListRowBackground()

            // MARK: - 引导
            Section {
                Button {
                    onboardingService.hasCompletedOnboarding = false
                    SplashPresentationPolicy.resetSplashState(keyStore: keyStore)
                    toastManager.show(type: .success, message: L10n.Settings.developer.resetOnboardingDone)
                } label: {
                    HStack {
                        Label(L10n.Settings.developer.showWelcomeBanner, systemImage: DesignTokens.Icons.sparkles)
                            .foregroundStyle(.appText)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                    Task {
                        let resetDelayNs: UInt64 = 400_000_000
                        try? await Task.sleep(nanoseconds: resetDelayNs)
                        onboardingService.reset()
                        SplashPresentationPolicy.resetSplashState(keyStore: keyStore)
                    }
                } label: {
                    HStack {
                        Label(L10n.Settings.developer.showGuidePage, systemImage: DesignTokens.Icons.questionCircle)
                            .foregroundStyle(.appText)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text(L10n.Settings.developer.section.onboarding)
            }
            .appListRowBackground()
        }
            .appGroupedFormStyle()
            .scrollContentBackground(.hidden)
            .tint(Color.appAccent)
            .background {
                if !isEmbedded {
                    PageBackgroundView(accentColor: Color.theme.blue)
                }
            }
            .navigationTitle(L10n.Settings.Section.developer)
            .toolbar {
                if !isEmbedded {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.Common.done) { dismiss() }
                    }
                }
            }
            .appToast() // 确保在二级导航页面也能正确渲染 Toast，解决被遮挡问题
            .confirmationDialog(L10n.Settings.developer.stressTest.confirmTitle, isPresented: $showStressTestConfirmation, titleVisibility: .visible) {
                Button(L10n.Settings.developer.stressTest.confirmAction(stressTestTargetCount), role: .destructive) {
                    // Bug #58 修复：在启动 Task 前同步设置 isStressTesting，避免按钮在
                    // Task 异步设置标志前被重复点击导致并发压力测试。
                    guard !isStressTesting else { return }
                    isStressTesting = true
                    Task { await runStressTest(count: stressTestTargetCount) }
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Settings.developer.stressTest.confirmMessage)
            }
        }

    private func runStressTest(count targetCount: Int) async {
        // Bug #58 修复：isStressTesting 已由调用方同步设置，此处不再重复设置。
        // 确保两个默认演示笔记本存在，不存在则创建
        let vaultService = ServiceContainer.shared.resolve(VaultService.self) // inject_exempt: 有意保留（需要具体 VaultService 类型而非协议）
        let demoVaultNames = [L10n.Vault.defaultName, L10n.Vault.researchName]
        for name in demoVaultNames where !vaultService.vaults.contains(where: { $0.name == name }) {
                vaultService.createVault(name: name)
        }

        // 对两个默认笔记本注入压力测试数据
        var totalCount = 0
        var lastError: Error?
        for vault in vaultService.vaults where demoVaultNames.contains(vault.name) {
            do {
                try await vaultService.selectVaultAndWait(vault)
                let count = (try? await InitialNotebookGenerator.generateStressTestNotebooks(in: store.pageStore, count: targetCount)) ?? 0
                totalCount += count
            } catch {
                // Bug #59 修复：记录最后一个错误，不再静默吞掉。
                lastError = error
            }
        }

        await MainActor.run {
            self.stressTestCount = totalCount
            self.isStressTesting = false
            // Bug #59 修复：totalCount==0 或有错误时不应视为成功。
            if totalCount == 0 || lastError != nil {
                Logger.shared.addLog(
                    action: .error,
                    target: FeatureConstants.DeveloperLogTarget.stressTest,
                    details: L10n.Settings.developer.stressTest.noDataInjected + (lastError.map { ": \($0.localizedDescription)" } ?? "")
                )
            }
            Task {
                await knowledgeStore.refresh()
                // Bug #60 修复：压力测试是注入数据而非清空，应发布图谱重布局事件而非 pagesCleared。
                // pagesCleared 语义为"清空所有页面"，会触发 AppStore/MedalService/KnowledgeStore 的清空逻辑。
                AppEventBus.shared.publish(.graphRelayoutRequested)
            }
        }
    }

}

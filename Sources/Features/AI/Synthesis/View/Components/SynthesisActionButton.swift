//
//  SynthesisActionButton.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：AI 合成实验室：摘要、思维导图、测验、报告生成。
//
import SwiftUI
import Dependencies

/// 合成操作启动按钮组件
/// 负责单个合成任务（如思维导图生成）的触发逻辑、前置校验、生成进度展示及超限状态控制
struct SynthesisActionButton: View {
    @Dependency(\.toastService) private var toastManager
    let type: SynthesisStore.SynthesisType
    let store: AppStore
    @Environment(SynthesisStore.self) var synthesisStore
    
    @EnvironmentObject var llmService: LLMService
    @Binding var showNoPagesAlert: Bool
    @Binding var showLimitAlert: Bool
    @Binding var showLLMAlert: Bool
    @Binding var selectedFilterType: SynthesisStore.SynthesisType?
    @Binding var selectedDoc: SynthesisStore.SynthesisDocument?
    @Binding var showOutput: Bool
    
    @State private var showControlSheet = false

    var body: some View {
        let state = synthesisStore.synthesisStates[type] ?? .idle
        let currentCount = synthesisStore.synthesisResults[type]?.count ?? 0
        let isLimitReached = currentCount >= synthesisStore.maxSynthesisDocsPerType
        
        VStack(spacing: DesignSystem.tightPadding) {
            ZStack(alignment: .topTrailing) {
                Button(action: { 
                    HapticFeedback.shared.trigger(.selection)
                    performSynthesis(options: nil)
                }) {
                    VStack(spacing: DesignSystem.tiny) {
                        ZStack {
                            Circle().fill(type.formatColor.opacity(SystemOpacity.faint)).frame(width: DesignSystem.Metrics.largeIconBoxSize, height: DesignSystem.Metrics.largeIconBoxSize)
                            Image(systemName: type.icon)
                                .font(.system(size: DesignSystem.iconMedium, weight: .semibold))
                                .foregroundStyle(type.formatColor)
                                .opacity(state == .generating ? DesignSystem.dimmedOpacity : DesignSystem.fullOpacity)
                            
                            if state == .generating {
                                ProgressView()
                                    .scaleEffect(DesignSystem.Animation.pressScale)
                                    .tint(type.formatColor)
                            }
                        }
                        Text(type.title)
                            .font(.system(size: DesignSystem.Metrics.dashboardLabelSize, weight: .bold))
                            .foregroundStyle(.appText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.standardPadding)
                    .appMetricCardStyle(color: type.formatColor, cornerRadius: DesignSystem.standardRadius)
                }
                .buttonStyle(AppCardButtonStyle())
                .disabled(state == .generating)

                // 🌟 右侧 NotebookLM 风格独立控制/定制按钮
                Button {
                    HapticFeedback.shared.trigger(.selection)
                    showControlSheet = true
                } label: {
                    Image(systemName: DesignSystem.Icons.sliderHorizontal)
                        .font(.system(size: DesignSystem.iconTiny, weight: .bold))
                        .foregroundStyle(type.formatColor)
                        .padding(DesignSystem.tightPadding)
                        .background(Color.appCard.opacity(DesignSystem.surfaceOpacity))
                        .clipShape(Circle())
                        .shadow(radius: SystemShadow.radiusSmall)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.AI.Synthesis.Control.title)
                .padding(DesignSystem.tiny)
                .disabled(state == .generating)
            }
            .contextMenu {
                Button {
                    performSynthesis(options: nil)
                } label: {
                    Label(L10n.AI.Status.generating, systemImage: DesignSystem.Icons.boltFill)
                }
                
                Button {
                    showControlSheet = true
                } label: {
                    Label(L10n.AI.Synthesis.Control.title, systemImage: DesignSystem.Icons.sliderHorizontal)
                }
            }
            .animation(.spring(response: DesignSystem.Animation.springResponse, dampingFraction: DesignSystem.Animation.springDamping), value: state)
            .animation(.spring(response: DesignSystem.Animation.springResponse, dampingFraction: DesignSystem.Animation.springDamping), value: isLimitReached)
            .sheet(isPresented: $showControlSheet) {
                SynthesisControlSheet(type: type) { options in
                    performSynthesis(options: options)
                }
            }
            
            if isLimitReached {
                Text(L10n.AI.Synthesis.limitReachedWarning)
                    .font(.system(size: DesignSystem.microFontSize, weight: .medium))
                    .foregroundStyle(Color.theme.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func performSynthesis(options: SynthesisControlOptions?) {
        // Pre-check: LLM Config (Key, URL, Model)
        if !llmService.isReady {
            HapticFeedback.shared.trigger(.error)
            showLLMAlert = true
            return
        }
        
        Task {
            if store.pages.isEmpty {
                await store.refresh()
            }
            
            let activePages = store.pages
            if activePages.isEmpty {
                await MainActor.run {
                    HapticFeedback.shared.trigger(.error)
                    showNoPagesAlert = true
                }
                return
            }
            
            // 自动容量管控机制：SynthesisStore 内部已实现滚动覆写最旧文档，无需在此阻断用户发起新的合成
            
            var combinedContent = activePages.map { "# \($0.title)\n\($0.content)" }.joined(separator: "\n\n---\n\n")
            if let options, !options.customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                combinedContent += "\n\n[用户定制需求/侧重点说明]: \(options.customPrompt)"
            }
            let sourceIDs = activePages.map(\.id)
            
            do {
                _ = try await synthesisStore.performSynthesis(type: type, combinedContent: combinedContent, sourcePageIDs: sourceIDs)
                await MainActor.run {
                    HapticFeedback.shared.trigger(.success)
                    withAnimation(DesignSystem.standardAnimation) {
                        if selectedFilterType != nil && selectedFilterType != type {
                            selectedFilterType = nil
                        }
                    }
                    toastManager.show(type: .success, message: L10n.AI.Task.statusCompleted)
                }
            } catch {
                await MainActor.run {
                    HapticFeedback.shared.trigger(.error)
                    toastManager.show(type: .error, message: error.localizedDescription)
                }
            }
        }
    }
}

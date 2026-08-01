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

/// 合成操作启动按钮组件
/// 负责单个合成任务（如思维导图生成）的触发逻辑、前置校验、生成进度展示及超限状态控制
struct SynthesisActionButton: View {
    let type: SynthesisStore.SynthesisType
    let store: AppStore
    @Environment(SynthesisStore.self) var synthesisStore
    
    @EnvironmentObject var llmService: LLMService
    @Binding var showNoPagesAlert: Bool
    @Binding var showLimitAlert: Bool
    @Binding var showLLMAlert: Bool
    
    var body: some View {
        let state = synthesisStore.synthesisStates[type] ?? .idle
        let currentCount = synthesisStore.synthesisResults[type]?.count ?? 0
        let isLimitReached = currentCount >= synthesisStore.maxSynthesisDocsPerType
        
        VStack(spacing: DesignSystem.tightPadding) {
            Button(action: { 
                HapticFeedback.shared.trigger(.selection)
                
                // Pre-check: LLM Config (Key, URL, Model)
                if !llmService.isReady {
                    HapticFeedback.shared.trigger(.error)
                    showLLMAlert = true
                    return
                }
                
                if store.pages.isEmpty {
                    HapticFeedback.shared.trigger(.error)
                    showNoPagesAlert = true
                    return
                }
                
                if isLimitReached {
                    HapticFeedback.shared.trigger(.error)
                    showLimitAlert = true
                    return
                }
                
                let combinedContent = store.pages.map { "# \($0.title)\n\($0.content)" }.joined(separator: "\n\n---\n\n")
                let sourceIDs = store.pages.map(\.id)
                Task {
                    ToastManager.shared.show(type: .processing, message: L10n.Common.aiThinking, duration: 0)
                    do {
                        _ = try await synthesisStore.performSynthesis(type: type, combinedContent: combinedContent, sourcePageIDs: sourceIDs)
                        HapticFeedback.shared.trigger(.success)
                        ToastManager.shared.show(type: .success, message: L10n.AI.Task.statusCompleted)
                    } catch {
                        HapticFeedback.shared.trigger(.error)
                        ToastManager.shared.show(type: .error, message: error.localizedDescription)
                    }
                }
            }) {
                VStack(spacing: DesignSystem.tiny) {
                    ZStack {
                        Circle().fill(type.formatColor.opacity(DesignSystem.dimmedOpacity * 0.6)).frame(width: DesignSystem.Metrics.largeIconBoxSize, height: DesignSystem.Metrics.largeIconBoxSize) // 0.12
                        Image(systemName: type.icon)
                            .font(.system(size: DesignSystem.iconMedium, weight: .semibold))
                            .foregroundStyle(type.formatColor)
                            .opacity((state == .generating || isLimitReached) ? DesignSystem.dimmedOpacity : DesignSystem.fullOpacity)
                        
                        if state == .generating {
                            ProgressView()
                                .scaleEffect(DesignSystem.Animation.pressScale) // 0.9
                                .tint(type.formatColor)
                        } else if isLimitReached {
                            Image(systemName: DesignSystem.Icons.lock)
                                .font(.system(size: DesignSystem.iconTiny, weight: .bold))
                                .foregroundStyle(.red.opacity(DesignSystem.secondaryOpacity))
                        }
                    }
                    Text(type.title)
                        .font(.system(size: DesignSystem.Metrics.dashboardLabelSize, weight: .bold))
                        .foregroundStyle(isLimitReached ? .appSecondary : .appText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.standardPadding)
                .appMetricCardStyle(color: type.formatColor, cornerRadius: DesignSystem.standardRadius)
            }
            .buttonStyle(AppCardButtonStyle())
            .disabled(state == .generating || isLimitReached)
            .animation(.spring(response: DesignSystem.Animation.springResponse, dampingFraction: DesignSystem.Animation.springDamping), value: state)
            .animation(.spring(response: DesignSystem.Animation.springResponse, dampingFraction: DesignSystem.Animation.springDamping), value: isLimitReached)
            
            if isLimitReached {
                Text(L10n.AI.Synthesis.limitReachedWarning)
                    .font(.system(size: DesignSystem.microFontSize, weight: .medium))
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

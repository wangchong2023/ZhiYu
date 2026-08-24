//
//  AIPulseIndicator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：AI 对话功能：多轮对话、流式响应、聊天历史管理。
//
import SwiftUI
import Observation
import Dependencies

/// AI 脉搏指示器
/// 负责增强用户对 AI 处理状态（如思考、全库扫描）的感知，提供动态波纹动画及实时状态文本展示
struct AIPulseIndicator: View {
    @Environment(AppStore.self) var store
    @Dependency(\.taskCenter) private var taskCenter
    private var isAIProcessing: Bool {
        taskCenter.tasks.contains(where: { task in
            if case .running = task.status {
                return task.type == .ai || task.type == .synthesis
            }
            return false
        })
    }
    
    private var isActive: Bool {
        isAIProcessing || store.isScanningAI
    }
    
    private var currentStage: TaskStage {
        if let runningTask = taskCenter.tasks.first(where: { if case .running = $0.status { return true }; return false }) {
            if case .running(_, let stage) = runningTask.status {
                return stage
            }
        }
        return .general
    }
    
    private var pulseColor: Color {
        if isAIProcessing {
            switch currentStage {
            case .embedding: return .cyan
            case .retrieval: return .blue
            case .synthesis: return .purple
            default: return .purple
            }
        } else if store.isScanningAI {
            return .appAccent // 正在全库扫描 (Orange)
        }
        return .appSecondary.opacity(DesignSystem.disabledOpacity) // 0.3
    }

    private var waveformSpeed: Double {
        switch currentStage {
        case .embedding: return 2.2  // 计算密集，极快速度
        case .retrieval: return 1.4  // 检索等待，中速波纹
        case .synthesis: return 0.6  // 慢速优雅吐字
        default: return 1.0
        }
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.small) { // 8
            ZStack {
                if isActive {
                    // 全新 Siri-like 霓虹正弦波形动效 (SR-12)
                    SiriWaveformView(speedMultiplier: waveformSpeed, amplitudeMultiplier: 0.7)
                        .frame(width: DesignSystem.IconSize.huge, height: 16)
                } else {
                    Circle()
                        .fill(pulseColor)
                        .frame(width: DesignSystem.smallIconSize / 2, height: DesignSystem.smallIconSize / 2) // 8
                }
            }
            
            if isActive {
                VStack(alignment: .leading, spacing: DesignSystem.atomic) { // 2
                    Text(currentStageTitle)
                        .font(.system(size: DesignSystem.microFontSize, weight: .bold, design: .rounded)) // 10
                        .foregroundStyle(pulseColor)
                    
                    if !taskCenter.latestStatus.isEmpty {
                        Text(taskCenter.latestStatus)
                            .font(.system(size: DesignSystem.microFontSize - 2, design: .monospaced)) // 8
                            .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.prominent)) // 0.8
                            .lineLimit(1)
                            .transition(.asymmetric(insertion: .push(from: .bottom), removal: .opacity))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .padding(.horizontal, DesignSystem.small + DesignSystem.atomic) // 10
        .padding(.vertical, DesignSystem.tiny + DesignSystem.atomic) // 6
        .background(
            Capsule()
                .fill(Color.appCard.opacity(DesignSystem.Opacity.prominent)) // 0.8
                .shadow(color: .black.opacity(DesignSystem.shadowOpacity / 2), radius: SystemStroke.selected) // 0.05, 2
        )
        .animation(.spring(response: DesignSystem.Animation.standardDuration * 1.2), value: taskCenter.latestStatus) // 0.3
        .animation(.spring(), value: isActive)
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startHapticPulse()
            }
        }
    }

    private var currentStageTitle: String {
        if !isAIProcessing && store.isScanningAI {
            return L10n.AI.Status.scanning
        }
        switch currentStage {
        case .embedding: return "VECTORIZING..."
        case .retrieval: return "RETRIEVING..."
        case .synthesis: return L10n.AI.Status.thinking
        default: return L10n.AI.Status.thinking
        }
    }
    
    private func startHapticPulse() {
        Task {
            while isActive {
                HapticFeedback.shared.trigger(.pulse)
                try? await Task.sleep(nanoseconds: UInt64(DesignSystem.Animation.AI.pulseInterval * 1_000_000_000))
            }
        }
    }
}

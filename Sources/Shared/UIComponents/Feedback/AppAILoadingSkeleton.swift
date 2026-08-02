//
//  AppAILoadingSkeleton.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI
import UFPDesignSystem

/// 增强型 AI 骨架屏
/// 支持展示当前的 RAG 阶段，并提供类似神经元跳动的动画效果
public struct AppAILoadingSkeleton: View {
    let stage: TaskStage
    
    public init(stage: TaskStage = .general) {
        self.stage = stage
    }
    
    private var stageColor: Color {
        switch stage {
        case .embedding: return .cyan
        case .retrieval: return .blue
        case .synthesis: return .purple
        default: return .appAccent
        }
    }
    
    /// 当前 AI 任务执行阶段的本地化提示文案
    private var stageText: String {
        switch stage {
        case .embedding: return L10n.Chat.skeleton.embedding
        case .retrieval: return L10n.Chat.skeleton.retrieval
        case .synthesis: return L10n.Chat.skeleton.synthesis
        default: return L10n.Chat.skeleton.thinking
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            // 1. 顶部状态标签
            HStack(spacing: DesignSystem.small) {
                AppLottieView(name: "ai_thinking")
                    .frame(width: DesignSystem.IconSize.standard, height: DesignSystem.IconSize.standard)
                
                Text(stageText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(stageColor)
            }
            .padding(.horizontal, DesignSystem.small)
            .padding(.vertical, DesignSystem.tiny)
            .background(stageColor.opacity(DesignSystem.Opacity.subtle))
            .clipShape(Capsule())
            
            // 2. 多行模拟文本骨架
            VStack(alignment: .leading, spacing: DesignSystem.small) {
                skeletonRow(widthRatio: 0.9)
                skeletonRow(widthRatio: 0.85)
                skeletonRow(widthRatio: 0.6)
            }
        }
        .padding(DesignSystem.medium)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.mediumRadius)
                .stroke(stageColor.opacity(DesignSystem.Opacity.subtle), lineWidth: 1)
        )
    }
    
    private func skeletonRow(widthRatio: CGFloat) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: DesignSystem.microRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            stageColor.opacity(DesignSystem.Opacity.ghost),
                            stageColor.opacity(DesignSystem.Opacity.glass),
                            stageColor.opacity(DesignSystem.Opacity.ghost)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: geo.size.width * widthRatio, height: 12)
                .shimmerApp()
        }
        .frame(height: DesignSystem.medium)
    }
}

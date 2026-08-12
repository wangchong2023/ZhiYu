//
//  AIProcessingStatusBanner.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI
import Dependencies

/// 全局 AI 任务处理状态条
struct AIProcessingStatusBanner: View {
    @Dependency(\.taskCenter) var taskCenter
    @State private var rotationAngle: Double = 0
    @State private var isAnimating = false
    
    var body: some View {
        if let activeTask = taskCenter.tasks.first(where: { 
            if case .running = $0.status { return true }
            if case .pending = $0.status { return true }
            return false
        }) {
            VStack(spacing: 0) {
                HStack(spacing: DesignSystem.medium) {
                    // 1. 动态 AI 思考图标
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.appAccent.opacity(DesignSystem.Opacity.medium), .purple.opacity(DesignSystem.Opacity.medium)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: DesignSystem.IconSize.large, height: DesignSystem.IconSize.large)
                        
                        Image(systemName: DesignSystem.Icons.sparkles)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(LinearGradient(colors: [.appAccent, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .rotationEffect(.degrees(rotationAngle))
                    }
                    
                    // 2. 任务状态文本
                    VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                        Text(activeTask.name)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.appText)
                        
                        Text(taskCenter.latestStatus.isEmpty ? L10n.AI.Task.processing : taskCenter.latestStatus)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // 3. 进度指示 (如果是执行中)
                    if case .running(let progress, _) = activeTask.status {
                        Text("\(Int(progress * 100))%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.appAccent)
                    }
                }
                .padding(.horizontal, DesignSystem.medium)
                .padding(.vertical, 10)
                .background(Color.appCard.opacity(DesignSystem.Opacity.prominent))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.cardRadius, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.appAccent.opacity(DesignSystem.Opacity.shadow), .purple.opacity(DesignSystem.Opacity.subtle)], startPoint: .leading, endPoint: .trailing), lineWidth: 1)
                )
                .shadow(color: .black.opacity(DesignSystem.Opacity.ghost), radius: 10, y: 5)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                startAnimation()
            }
        } else {
            EmptyView()
        }
    }
    
    private func startAnimation() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
}

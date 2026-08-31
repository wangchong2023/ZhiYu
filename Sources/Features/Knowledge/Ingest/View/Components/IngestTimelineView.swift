//
//  IngestViewComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：知识摄入：文档导入、URL 抓取、OCR 扫描、PDF 解析。
//
import SwiftUI
import UFPDesignSystem

// MARK: - Ingest Timeline View

// Lottie 动画资源名常量（资源标识符，非用户可见文本）
private enum IngestLottieAnimation {
    static let processing = "ingest_processing"
}

/// Ingest 细粒度子状态实时反馈时间轴组件
/// 提供带有呼吸动画、进度连线、玻璃态和当前日志打字机效果的动态视图
struct IngestTimelineView: View {
    let currentStage: TaskStage
    let subLogs: [String]
    
    private struct StageItem: Identifiable {
        let id: TaskStage
        let title: String
        let icon: String
        let color: Color
    }
    
    private let stages: [StageItem] = [
        StageItem(id: .extraction, title: L10n.Ingest.Status.starting, icon: "doc.text.magnifyingglass", color: Color.theme.gray),
        StageItem(id: .enrichment, title: L10n.Ingest.Status.aiEnriching, icon: "sparkles", color: Color.theme.indigo),
        StageItem(id: .chunking, title: L10n.Ingest.Status.chunking, icon: "square.grid.3x3", color: Color.theme.cyan),
        StageItem(id: .embedding, title: L10n.Ingest.Status.vectorizing, icon: "server.rack", color: Color.theme.teal)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                HStack(alignment: .top, spacing: DesignSystem.medium) {
                    // 左侧图标与连线
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(isCompleted(stage.id) ? stage.color : (isActive(stage.id) ? stage.color.opacity(DesignSystem.Opacity.medium) : Color.appCard))
                                .frame(width: DesignSystem.IconSize.standard, height: DesignSystem.IconSize.standard)
                            
                            if isActive(stage.id) {
                                AppLottieView(name: IngestLottieAnimation.processing)
                                    .frame(width: DesignSystem.IconSize.large, height: DesignSystem.IconSize.large)
                            }
                            
                            Image(systemName: isCompleted(stage.id) ? "checkmark" : stage.icon)
                                .font(.system(size: SystemFontSize.micro, weight: .bold)) // Dynamic Type
                                .foregroundStyle(isCompleted(stage.id) ? .white : (isActive(stage.id) ? stage.color : .appSecondary.opacity(DesignSystem.Opacity.soft)))
                        }
                        
                        if index < stages.count - 1 {
                            Rectangle()
                                .fill(isCompleted(stage.id) ? stage.color : Color.appBorder)
                                .frame(width: DesignSystem.atomic)
                                .frame(minHeight: isActive(stage.id) ? 30 : 16)
                                .padding(.vertical, SystemSpacing.atomic)
                        }
                    }
                    
                    // 右侧内容
                    VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                        Text(stage.title)
                            .font(.subheadline.weight(isActive(stage.id) ? .bold : .medium))
                            .foregroundStyle(isActive(stage.id) ? stage.color : (isCompleted(stage.id) ? .appText : .appSecondary.opacity(DesignSystem.Opacity.soft)))
                            .padding(.top, SystemSpacing.atomic)
                        
                        // 只在当前活跃阶段显示最新的子日志
                        if isActive(stage.id), let latestLog = subLogs.last {
                            Text(latestLog)
                                .font(.system(size: DesignSystem.captionFontSize, design: .monospaced))
                                .foregroundStyle(.appSecondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .animation(.easeOut(duration: 0.3), value: latestLog)
                        }
                    }
                    .padding(.bottom, index < stages.count - 1 ? DesignSystem.small : 0)
                }
            }
        }
    }
    
    private func isActive(_ stage: TaskStage) -> Bool {
        return currentStage == stage
    }
    
    private func isCompleted(_ stage: TaskStage) -> Bool {
        let order: [TaskStage] = [.pending, .extraction, .enrichment, .chunking, .embedding]
        guard let currentIndex = order.firstIndex(of: currentStage),
              let targetIndex = order.firstIndex(of: stage) else { return false }
        return currentIndex > targetIndex
    }
}

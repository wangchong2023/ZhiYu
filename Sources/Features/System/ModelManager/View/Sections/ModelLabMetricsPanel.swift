//
//  ModelLabMetricsPanel.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：实时性能评估看板（速度/延迟/内存指标卡片）与流式推理输出展示板的渲染。
//

import SwiftUI

// MARK: - 性能监控与输出面板

extension ModelLabView {

    /// 实时评估性能指标看板
    var metricsMonitorBoard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            HStack(spacing: DesignSystem.tiny) {
                Image(systemName: "cpu")
                    .foregroundStyle(.cyan)
                Text(L10n.ModelManager.Lab.performanceMetrics)
                    .font(.caption.bold())
                    .foregroundStyle(.cyan)
            }
            .padding(.horizontal, 4)

            HStack(spacing: DesignSystem.small) {
                metricItemCard(
                    title: L10n.ModelManager.Lab.speed,
                    value: String(format: "%.1f", labManager.currentStats.speed),
                    unit: "Tok/s",
                    glowColor: .cyan
                )
                metricItemCard(
                    title: L10n.ModelManager.Lab.prefillLatency,
                    value: "\(labManager.currentStats.prefillLatency)",
                    unit: "ms",
                    glowColor: .purple
                )
                metricItemCard(
                    title: L10n.ModelManager.Lab.firstTokenLatency,
                    value: "\(labManager.currentStats.firstTokenLatency)",
                    unit: "ms",
                    glowColor: .blue
                )
                metricItemCard(
                    title: L10n.ModelManager.Lab.memoryUsage,
                    value: String(format: "%.0f", labManager.currentStats.memoryUsage),
                    unit: "MB",
                    glowColor: .teal
                )
            }
        }
        .padding(DesignSystem.medium)
        .background(.ultraThinMaterial)
        .cornerRadius(DesignSystem.mediumRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.mediumRadius)
                .stroke(
                    LinearGradient(
                        colors: [.cyan.opacity(DesignSystem.softOpacity), .purple.opacity(DesignSystem.shadowOpacity)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    /// 单个带渐变边框发光的科技微面板
    func metricItemCard(title: String, value: String, unit: String, glowColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.appSecondary)

            Text(value)
                .font(.system(.title3, design: .rounded))
                .bold()
                .foregroundStyle(.appText)
                .contentTransition(.numericText()) // 动画数字翻滚

            Text(unit)
                .font(.caption2.weight(.bold))
                .foregroundStyle(glowColor.opacity(DesignSystem.Opacity.prominent))
        }
        .padding(.vertical, DesignSystem.small)
        .frame(maxWidth: .infinity)
        .background(Color.appCard.opacity(DesignSystem.Opacity.ghost))
        .cornerRadius(DesignSystem.smallRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                .stroke(
                    LinearGradient(
                        colors: [glowColor.opacity(DesignSystem.softOpacity), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: labManager.isGenerating ? glowColor.opacity(DesignSystem.glassOpacity) : .clear, radius: 4, x: 0, y: 0)
    }

    // MARK: - 辅助子视图（高精度 AI 模拟效果展示）

    private func confidenceRow(name: String, score: Double, color: Color) -> some View {
        HStack(spacing: DesignSystem.small) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.appText)
                .frame(width: DesignSystem.Metrics.sourceCardWidth - DesignSystem.tiny, alignment: .leading)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DesignSystem.microRadius)
                    .fill(Color.appBorder.opacity(DesignSystem.dimmedOpacity))
                    .frame(height: DesignSystem.Metrics.progressHeight)

                RoundedRectangle(cornerRadius: DesignSystem.microRadius)
                    .fill(color)
                    .frame(width: DesignSystem.Metrics.boxHeight * CGFloat(score), height: DesignSystem.Metrics.progressHeight)
                    .shadow(color: color.opacity(DesignSystem.softOpacity), radius: 2)
            }
            .frame(width: DesignSystem.Metrics.boxHeight)

            Spacer()

            Text(String(format: "%.0f%%", score * 100))
                .font(.caption2.monospaced())
                .foregroundStyle(color)
                .bold()
        }
    }

    private func transcriptionSegment(time: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.small) {
            Text(time)
                .font(.system(size: DesignSystem.caption2FontSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(DesignSystem.subtleFillOpacity))
                .cornerRadius(DesignSystem.microRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.microRadius)
                        .stroke(color.opacity(DesignSystem.accentStrokeOpacity), lineWidth: 0.5)
                )

            Text(text)
                .font(.caption)
                .foregroundStyle(.appText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private func traceStepRow(title: String, desc: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.small) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.appText)
                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func parseColor(from name: String) -> Color {
        switch name {
        case "cyan": return .cyan
        case "purple": return .purple
        case "blue": return .blue
        case "green": return .green
        default: return .cyan
        }
    }

    @ViewBuilder
    private func specializedResultPanel(for useCase: UseCaseType) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            Text(labManager.extraPanelTitle)
                .font(.caption.bold())
                .foregroundStyle(.cyan)
            
            if useCase == .askImage {
                VStack(spacing: 8) {
                    ForEach(labManager.confidenceItems) { item in
                        confidenceRow(name: item.name, score: item.score, color: parseColor(from: item.colorName))
                    }
                }
                .padding(DesignSystem.small)
                .background(Color.appBackground.opacity(DesignSystem.disabledOpacity))
                .cornerRadius(DesignSystem.smallRadius)
            } else if useCase == .audioScribe {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(labManager.traceSteps) { item in
                        transcriptionSegment(time: item.title, text: item.desc, color: parseColor(from: item.colorName))
                    }
                }
                .padding(DesignSystem.small)
                .background(Color.appBackground.opacity(DesignSystem.disabledOpacity))
                .cornerRadius(DesignSystem.smallRadius)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(labManager.traceSteps) { item in
                        traceStepRow(title: item.title, desc: item.desc, icon: item.icon, color: parseColor(from: item.colorName))
                    }
                }
                .padding(DesignSystem.small)
                .background(Color.appBackground.opacity(DesignSystem.disabledOpacity))
                .cornerRadius(DesignSystem.smallRadius)
            }
        }
    }

    /// 流式输出面板
    var outputScribeBoard: some View {
        let useCase = labManager.selectedUseCase ?? .aiChat
        return VStack(alignment: .leading, spacing: DesignSystem.small) {
            Text(L10n.ModelManager.Lab.outputResult)
                .font(.subheadline.bold())
                .foregroundStyle(.appText)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    // 主推理文本流
                    Text(labManager.generatedText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.appText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    
                    // 当有数据时展示特化面板
                    if !labManager.generatedText.isEmpty, !labManager.extraPanelTitle.isEmpty {
                        Divider()
                            .padding(.vertical, DesignSystem.tiny)
                        
                        specializedResultPanel(for: useCase)
                    }
                }
            }
            .frame(height: DesignSystem.Vault.cardHeight + DesignSystem.Metrics.iconBoxSize)
            .padding(DesignSystem.standardPadding + DesignSystem.tiny)
            .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
            .cornerRadius(DesignSystem.smallRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                    .stroke(Color.appBorder.opacity(DesignSystem.Opacity.subtle), lineWidth: 1)
            )
        }
        .padding(DesignSystem.medium)
        .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
        .cornerRadius(DesignSystem.mediumRadius)
    }
}

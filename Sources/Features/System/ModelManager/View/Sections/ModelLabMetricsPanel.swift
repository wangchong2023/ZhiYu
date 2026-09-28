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
import UFPDesignSystem

// MARK: - 性能监控与输出面板

extension ModelLabView {

    /// 实时评估性能指标看板
    var metricsMonitorBoard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack(spacing: DesignTokens.Spacing.tiny) {
                Image(systemName: DesignTokens.Icons.cpuOutline)
                    .foregroundStyle(Color.theme.cyan)
                Text(L10n.ModelManager.Lab.performanceMetrics)
                    .font(.caption.bold())
                    .foregroundStyle(Color.theme.cyan)
            }
            .padding(.horizontal, DesignTokens.SystemSpacing.tiny)

            HStack(spacing: DesignTokens.Spacing.small) {
                metricItemCard(
                    title: L10n.ModelManager.Lab.speed,
                    value: String(format: "%.1f", labManager.currentStats.speed),
                    unit: FeatureConstants.UnitName.tokPerSec,
                    glowColor: Color.theme.cyan
                )
                metricItemCard(
                    title: L10n.ModelManager.Lab.prefillLatency,
                    value: "\(labManager.currentStats.prefillLatency)",
                    unit: FeatureConstants.UnitName.millisecond,
                    glowColor: Color.theme.purple
                )
                metricItemCard(
                    title: L10n.ModelManager.Lab.firstTokenLatency,
                    value: "\(labManager.currentStats.firstTokenLatency)",
                    unit: FeatureConstants.UnitName.millisecond,
                    glowColor: Color.theme.blue
                )
                metricItemCard(
                    title: L10n.ModelManager.Lab.memoryUsage,
                    value: String(format: "%.0f", labManager.currentStats.memoryUsage),
                    unit: FeatureConstants.UnitName.megabyte,
                    glowColor: Color.theme.teal
                )
            }
        }
        .padding(DesignTokens.Spacing.medium)
        .background(.ultraThinMaterial)
        .cornerRadius(DesignTokens.Spacing.mediumRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius)
                .stroke(
                    LinearGradient(
                        colors: [Color.theme.cyan.opacity(DesignTokens.Colors.Opacity.softOpacity), Color.theme.purple.opacity(DesignTokens.Spacing.shadowOpacity)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: DesignTokens.SystemStroke.divider
                )
        )
    }

    /// 单个带渐变边框发光的科技微面板
    func metricItemCard(title: String, value: String, unit: String, glowColor: Color) -> some View {
        VStack(spacing: DesignTokens.SystemSpacing.tiny) {
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
                .foregroundStyle(glowColor.opacity(DesignTokens.Opacity.prominent))
        }
        .padding(.vertical, DesignTokens.Spacing.small)
        .frame(maxWidth: .infinity)
        .background(Color.appCard.opacity(DesignTokens.Opacity.ghost))
        .cornerRadius(DesignTokens.SystemRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small)
                .stroke(
                    LinearGradient(
                        colors: [glowColor.opacity(DesignTokens.Colors.Opacity.softOpacity), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: DesignTokens.SystemStroke.border
                )
        )
        .shadow(color: labManager.isGenerating ? glowColor.opacity(DesignTokens.Colors.Opacity.glassOpacity) : .clear, radius: DesignTokens.SystemShadow.radiusSmall, x: 0, y: 0)
    }

    // MARK: - 辅助子视图（高精度 AI 模拟效果展示）

    private func confidenceRow(name: String, score: Double, color: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.appText)
                .frame(width: DesignTokens.Metrics.sourceCardWidth - DesignTokens.Spacing.tiny, alignment: .leading)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DesignTokens.Spacing.microRadius)
                    .fill(Color.appBorder.opacity(DesignTokens.Colors.Opacity.dimmedOpacity))
                    .frame(height: DesignTokens.Metrics.progressHeight)

                RoundedRectangle(cornerRadius: DesignTokens.Spacing.microRadius)
                    .fill(color)
                    // Bug #74 修复：钳制 score 到 [0, 1]，避免 score > 1 时进度条溢出容器。
                    .frame(width: DesignTokens.Metrics.boxHeight * CGFloat(min(max(score, 0.0), 1.0)), height: DesignTokens.Metrics.progressHeight)
                    .shadow(color: color.opacity(DesignTokens.Colors.Opacity.softOpacity), radius: DesignTokens.SystemShadow.radiusSmall)
            }
            .frame(width: DesignTokens.Metrics.boxHeight)

            Spacer()

            Text(String(format: "%.0f%%", score * FeatureConstants.PercentageBase.full))
                .font(.caption2.monospaced())
                .foregroundStyle(color)
                .bold()
        }
    }

    private func transcriptionSegment(time: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
            Text(time)
                .font(.system(size: DesignTokens.Typography.caption2FontSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, DesignTokens.SystemSpacing.small)
                .padding(.vertical, DesignTokens.SystemSpacing.atomic)
                .background(color.opacity(DesignTokens.Colors.subtleFillOpacity))
                .cornerRadius(DesignTokens.Spacing.microRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Spacing.microRadius)
                        .stroke(color.opacity(DesignTokens.Colors.Opacity.accentStrokeOpacity), lineWidth: DesignTokens.SystemStroke.hairline)
                )

            Text(text)
                .font(.caption)
                .foregroundStyle(.appText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, DesignTokens.SystemSpacing.atomic)
    }

    private func traceStepRow(title: String, desc: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .padding(.top, DesignTokens.SystemSpacing.atomic)

            VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.atomic) {
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
        .padding(.vertical, DesignTokens.SystemSpacing.atomic)
    }

    private func parseColor(from name: String) -> Color {
        switch name {
        case FeatureConstants.MockColorName.cyan: return Color.theme.cyan
        case FeatureConstants.MockColorName.purple: return Color.theme.purple
        case FeatureConstants.MockColorName.blue: return Color.theme.blue
        case FeatureConstants.MockColorName.green: return Color.theme.green
        default: return Color.theme.cyan
        }
    }

    @ViewBuilder
    private func specializedResultPanel(for useCase: UseCaseType) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text(labManager.extraPanelTitle)
                .font(.caption.bold())
                .foregroundStyle(Color.theme.cyan)
            
            if useCase == .askImage {
                VStack(spacing: DesignTokens.SystemSpacing.element) {
                    ForEach(labManager.confidenceItems) { item in
                        confidenceRow(name: item.name, score: item.score, color: parseColor(from: item.colorName))
                    }
                }
                .traceContainerStyle()
            } else if useCase == .audioScribe {
                VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.element) {
                    ForEach(labManager.traceSteps) { item in
                        transcriptionSegment(time: item.title, text: item.desc, color: parseColor(from: item.colorName))
                    }
                }
                .traceContainerStyle()
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.element) {
                    ForEach(labManager.traceSteps) { item in
                        traceStepRow(title: item.title, desc: item.desc, icon: item.icon, color: parseColor(from: item.colorName))
                    }
                }
                .traceContainerStyle()
            }
        }
    }

    /// 流式输出面板
    var outputScribeBoard: some View {
        let useCase = labManager.selectedUseCase ?? .aiChat
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text(L10n.ModelManager.Lab.outputResult)
                .font(.subheadline.bold())
                .foregroundStyle(.appText)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    // 主推理文本流
                    Text(labManager.generatedText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.appText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    
                    // 当有数据时展示特化面板
                    if !labManager.generatedText.isEmpty, !labManager.extraPanelTitle.isEmpty {
                        Divider()
                            .padding(.vertical, DesignTokens.Spacing.tiny)
                        
                        specializedResultPanel(for: useCase)
                    }
                }
            }
            .frame(height: DesignTokens.ComponentSpacing.chartHeight)
            .padding(DesignTokens.ComponentSpacing.section)
            .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
            .smallCardBorder()
        }
        .cardStyle(horizontalPadding: DesignTokens.Spacing.medium, verticalPadding: DesignTokens.Spacing.medium)
    }
}

/// 追踪容器样式修饰符，消除 askImage/audioScribe/default 分支的重复
private extension View {
    func traceContainerStyle() -> some View {
        self
            .padding(DesignTokens.Spacing.small)
            .background(Color.appBackground.opacity(DesignTokens.Colors.Opacity.disabledOpacity))
            .cornerRadius(DesignTokens.SystemRadius.small)
    }
}

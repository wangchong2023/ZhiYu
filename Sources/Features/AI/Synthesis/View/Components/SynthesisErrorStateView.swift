//
//  SynthesisErrorStateView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：AI 合成卡片统一用户友好型错误/降级处理视图（符合 Apple HIG 与标准 UX 规范）。
//

import SwiftUI

/// 用户友好型 AI 合成渲染异常处理视图
/// 替代原有的硬核报错堆栈与格式炸弹徽章，提供平滑美观的视觉沉浸卡片与明确的引导操作
struct SynthesisErrorStateView: View {
    // MARK: - Constants
    private enum Layout {
        static let iconCircleSize: CGFloat = ComponentSpacing.metricChipWidth
        static let iconFontSize: CGFloat = 36
        static let cardMinHeight: CGFloat = 320
    }

    let docType: SynthesisStore.SynthesisType
    var onSwitchToText: (() -> Void)?
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: DesignSystem.loosePadding) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                    .frame(width: Layout.iconCircleSize, height: Layout.iconCircleSize)

                Image(systemName: DesignSystem.Icons.sparkles)
                    .font(.system(size: Layout.iconFontSize, weight: .light)) // Dynamic Type
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.appAccent, .appAccent.opacity(DesignSystem.Opacity.dim)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.top, DesignSystem.medium)

            VStack(spacing: DesignSystem.small) {
                Text(L10n.AI.Synthesis.Error.invalidResult)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.appText)

                Text(L10n.AI.Synthesis.citationInstruction)
                    .font(.subheadline)
                    .foregroundStyle(.appSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.loosePadding)
            }

            HStack(spacing: DesignSystem.standardPadding) {
                if let onSwitchToText = onSwitchToText {
                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        onSwitchToText()
                    }) {
                        Label(L10n.AI.Synthesis.documentList, systemImage: DesignSystem.Icons.docPlaintext)
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
                }

                if let onRetry = onRetry {
                    Button(action: {
                        HapticFeedback.shared.trigger(.error)
                        onRetry()
                    }) {
                        Label(L10n.AI.Synthesis.Actions.regenerate, systemImage: DesignSystem.Icons.arrowClockwise)
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top, DesignSystem.small)
        }
        .padding(Spacing.Sidebar.backButtonWidth)
        .frame(maxWidth: .infinity, minHeight: Layout.cardMinHeight)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.largeRadius)
                .fill(Color.appCard)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.largeRadius)
                        .stroke(Color.appBorder.opacity(DesignSystem.Opacity.soft), lineWidth: DesignSystem.Metrics.dividerThickness)
                )
        )
        .padding(.horizontal, DesignSystem.standardPadding)
        .padding(.vertical, DesignSystem.medium)
    }
}

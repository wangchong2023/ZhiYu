//
//  ModelLabHeaderView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：实验室主页头部导语区（标题、活跃模型指示器）与用例格栅卡片网格的渲染。
//

import SwiftUI
import UFPDesignSystem

// MARK: - 头部与格栅

extension ModelLabView {

    /// 实验室头部导语区 (已简化，移除冲突大标题与活跃模型状态标签)
    var labHeaderView: some View {
        EmptyView()
    }

    /// 用例卡片列表
    var useCaseGridView: some View {
        LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.medium) {
            ForEach(UseCaseType.allCases) { useCase in
                useCaseCard(for: useCase)
            }
        }
    }

    /// 用例格栅单卡
    func useCaseCard(for useCase: UseCaseType) -> some View {
        let activeModel = getActiveModel()
        let isCompatible = activeModel.map { labManager.isModelCompatible($0, for: useCase) } ?? false

        return Button {
            if isCompatible {
                HapticFeedback.shared.trigger(.selection)
                labManager.selectedUseCase = useCase
                // 同步初始化默认超参
                if let model = activeModel {
                    loadParametersForModel(model.modelId)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                // 用例图标与兼容状态
                HStack {
                    Image(systemName: useCase.icon)
                        .font(.title2)
                        .foregroundStyle(isCompatible ? Color.theme.cyan : .secondary)

                    Spacer()

                    if !isCompatible {
                        Text(L10n.ModelManager.Lab.unsupported)
                            .font(.system(size: DesignTokens.SystemFontSize.micro))
                            .padding(.horizontal, DesignTokens.Spacing.standardPadding)
                            .padding(.vertical, DesignTokens.SystemSpacing.tiny)
                            .background(Color.theme.red.opacity(DesignTokens.Opacity.medium))
                            .foregroundStyle(Color.theme.red)
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, DesignTokens.Spacing.standardPadding)

                Text(useCase.title)
                    .font(.headline)
                    .foregroundStyle(isCompatible ? .appText : .secondary)

                Text(useCase.description)
                    .font(.caption)
                    .foregroundStyle(isCompatible ? .appText.opacity(DesignTokens.Colors.subtleOpacity) : .secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignTokens.Spacing.medium)
            .frame(minHeight: DesignTokens.Metrics.sourceCardHeight + DesignTokens.Spacing.large, alignment: .topLeading)
            // 暗黑毛玻璃态 (Glassmorphism)
            .background(.ultraThinMaterial.opacity(isCompatible ? DesignTokens.Opacity.shadow : DesignTokens.Opacity.glass))
            .cornerRadius(DesignTokens.Spacing.mediumRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius)
                    .stroke(
                        LinearGradient(
                            colors: isCompatible ? [.cyan.opacity(DesignTokens.Opacity.disabled), .purple.opacity(DesignTokens.Opacity.subtle)] : [.gray.opacity(DesignTokens.Opacity.subtle)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: DesignTokens.SystemStroke.divider
                    )
            )
            .shadow(color: isCompatible ? .cyan.opacity(DesignTokens.Opacity.light) : .clear, radius: DesignTokens.Spacing.shadowRadius, x: 0, y: DesignTokens.Spacing.shadowY)
        }
        .buttonStyle(.plain)
    }
}

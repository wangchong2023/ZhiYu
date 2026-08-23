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

// MARK: - 头部与格栅

extension ModelLabView {

    /// 实验室头部导语区 (已简化，移除冲突大标题与活跃模型状态标签)
    var labHeaderView: some View {
        EmptyView()
    }

    /// 用例卡片列表
    var useCaseGridView: some View {
        LazyVGrid(columns: columns, spacing: DesignSystem.medium) {
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
            VStack(alignment: .leading, spacing: DesignSystem.small) {
                // 用例图标与兼容状态
                HStack {
                    Image(systemName: useCase.icon)
                        .font(.title2)
                        .foregroundStyle(isCompatible ? .cyan : .secondary)

                    Spacer()

                    if !isCompatible {
                        Text(L10n.ModelManager.Lab.unsupported)
                            .font(.system(size: DesignSystem.iconTiny - 2))
                            .padding(.horizontal, DesignSystem.standardPadding)
                            .padding(.vertical, DesignSystem.standardPadding / 3)
                            .background(Color.theme.red.opacity(DesignSystem.Opacity.medium))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, DesignSystem.standardPadding)

                Text(useCase.title)
                    .font(.headline)
                    .foregroundStyle(isCompatible ? .appText : .secondary)

                Text(useCase.description)
                    .font(.caption)
                    .foregroundStyle(isCompatible ? .appText.opacity(DesignSystem.subtleOpacity) : .secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignSystem.medium)
            .frame(minHeight: DesignSystem.Metrics.sourceCardHeight + DesignSystem.large, alignment: .topLeading)
            // 暗黑毛玻璃态 (Glassmorphism)
            .background(.ultraThinMaterial.opacity(isCompatible ? DesignSystem.Opacity.shadow : DesignSystem.Opacity.glass))
            .cornerRadius(DesignSystem.mediumRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.mediumRadius)
                    .stroke(
                        LinearGradient(
                            colors: isCompatible ? [.cyan.opacity(DesignSystem.Opacity.disabled), .purple.opacity(DesignSystem.Opacity.subtle)] : [.gray.opacity(DesignSystem.Opacity.subtle)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: SystemStroke.divider
                    )
            )
            .shadow(color: isCompatible ? .cyan.opacity(DesignSystem.Opacity.light) : .clear, radius: DesignSystem.shadowRadius, x: SystemShadow.offsetNone, y: DesignSystem.shadowY)
        }
        .buttonStyle(.plain)
    }
}

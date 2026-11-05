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
    @ViewBuilder
    func useCaseCard(for useCase: UseCaseType) -> some View {
        let activeModel = getActiveModel()
        let readyModels = modelManager.remoteManifests.filter {
            modelManager.isModelLocalReady(for: $0.modelId) && labManager.isModelCompatible($0, for: useCase)
        }
        let allModels = modelManager.remoteManifests.filter {
            labManager.isModelCompatible($0, for: useCase)
        }
        let modelCount = allModels.count
        let readyCount = readyModels.count
        let isCompatible = modelCount > 0

        Button {
            if isCompatible {
                handleUseCaseSelection(for: useCase, activeModel: activeModel, readyModels: readyModels, allModels: allModels)
            }
        } label: {
            useCaseCardContent(for: useCase, isCompatible: isCompatible, readyCount: readyCount)
        }
        .buttonStyle(.plain)
    }

    /// 用例卡片内容视图
    @ViewBuilder
    private func useCaseCardContent(for useCase: UseCaseType, isCompatible: Bool, readyCount: Int) -> some View {
        let bgOpacity = isCompatible ? DesignTokens.Opacity.shadow : DesignTokens.Opacity.glass
        let shadowColor = isCompatible ? useCase.themeColor.opacity(DesignTokens.Opacity.light) : Color.clear

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            useCaseCardHeader(for: useCase, isCompatible: isCompatible, readyCount: readyCount)

            Text(useCase.title)
                .font(.headline)
                .foregroundStyle(isCompatible ? Color.appText : Color.secondary)

            Text(useCase.description)
                .font(.caption)
                .foregroundStyle(isCompatible ? Color.appText.opacity(DesignTokens.Colors.subtleOpacity) : Color.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: FeatureConstants.ModelLabSimulation.useCaseCardDescriptionHeight, alignment: .topLeading)

            Spacer(minLength: 0)
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, minHeight: FeatureConstants.ModelLabSimulation.useCaseCardMinHeight, alignment: .topLeading)
        .background(.ultraThinMaterial.opacity(bgOpacity))
        .cornerRadius(DesignTokens.Spacing.mediumRadius)
        .overlay(cardBorderOverlay(for: useCase, isCompatible: isCompatible))
        .shadow(color: shadowColor, radius: DesignTokens.Spacing.shadowRadius, x: 0, y: DesignTokens.Spacing.shadowY)
    }

    /// 用例卡片渐变边框遮罩
    private func cardBorderOverlay(for useCase: UseCaseType, isCompatible: Bool) -> some View {
        let colors: [Color] = isCompatible ?
            [useCase.themeColor.opacity(DesignTokens.Opacity.disabled), Color.theme.purple.opacity(DesignTokens.Opacity.subtle)] :
            [Color.theme.gray.opacity(DesignTokens.Opacity.subtle)]

        return RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius)
            .stroke(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: DesignTokens.SystemStroke.divider
            )
    }

    /// 用例卡片顶部图标与模型计数栏
    @ViewBuilder
    private func useCaseCardHeader(for useCase: UseCaseType, isCompatible: Bool, readyCount: Int) -> some View {
        HStack {
            useCaseIcon(for: useCase)
            Spacer()
            useCaseBadge(isCompatible: isCompatible, readyCount: readyCount)
        }
        .padding(.bottom, DesignTokens.Spacing.standardPadding)
    }

    /// 用例圆形彩色图标
    @ViewBuilder
    private func useCaseIcon(for useCase: UseCaseType) -> some View {
        ZStack {
            Circle()
                .fill(useCase.themeColor.opacity(DesignTokens.Opacity.disabled))
                .frame(width: DesignTokens.Spacing.Gallery.iconSize, height: DesignTokens.Spacing.Gallery.iconSize)

            Image(systemName: useCase.icon)
                .font(.title3)
                .foregroundStyle(useCase.themeColor)
        }
    }

    /// 用例可用状态或模型数量徽章
    @ViewBuilder
    private func useCaseBadge(isCompatible: Bool, readyCount: Int) -> some View {
        if isCompatible {
            if readyCount > 0 {
                Text(L10n.ModelManager.Lab.statusAvailable)
                    .font(.system(size: DesignTokens.SystemFontSize.micro, weight: .semibold))
                    .padding(.horizontal, DesignTokens.Spacing.standardPadding)
                    .padding(.vertical, DesignTokens.SystemSpacing.tiny)
                    .background(Color.theme.green.opacity(DesignTokens.Opacity.subtle))
                    .foregroundStyle(Color.theme.green)
                    .clipShape(Capsule())
            } else {
                Text(L10n.ModelManager.Lab.statusNeedDownload)
                    .font(.system(size: DesignTokens.SystemFontSize.micro, weight: .medium))
                    .padding(.horizontal, DesignTokens.Spacing.standardPadding)
                    .padding(.vertical, DesignTokens.SystemSpacing.tiny)
                    .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
                    .foregroundStyle(Color.secondary)
                    .clipShape(Capsule())
            }
        } else {
            Text(L10n.ModelManager.Lab.unsupported)
                .font(.system(size: DesignTokens.SystemFontSize.micro, weight: .medium))
                .padding(.horizontal, DesignTokens.Spacing.standardPadding)
                .padding(.vertical, DesignTokens.SystemSpacing.tiny)
                .background(Color.theme.red.opacity(DesignTokens.Opacity.medium))
                .foregroundStyle(Color.theme.red)
                .clipShape(Capsule())
        }
    }

    /// 处理用例选择与兼容模型激活
    private func handleUseCaseSelection(
        for useCase: UseCaseType,
        activeModel: LLMManifest?,
        readyModels: [LLMManifest],
        allModels: [LLMManifest]
    ) {
        HapticFeedback.shared.trigger(.selection)
        labManager.selectedUseCase = useCase
        if let active = activeModel, !labManager.isModelCompatible(active, for: useCase) {
            if let firstReady = readyModels.first {
                modelManager.activeModelId = firstReady.modelId
                loadParametersForModel(firstReady.modelId)
            } else if let firstCompatible = allModels.first {
                modelManager.activeModelId = firstCompatible.modelId
                loadParametersForModel(firstCompatible.modelId)
            }
        } else if let model = activeModel {
            loadParametersForModel(model.modelId)
        }
    }
}

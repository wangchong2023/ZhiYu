//
//  ModelLabConfigSheet.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：参数配置底部弹出 Sheet（仿 Google AI Edge Gallery Configurations），包含预设模板选择、
//  超参滑块组、CPU/GPU 加速器选择、高级开关、System Prompt 编辑器等分段配置面板。
//

import SwiftUI
import UFPDesignSystem

/// 端侧推理加速器后端选项
public enum InferenceAccelerator: String, CaseIterable, Identifiable, Sendable {
    case auto
    case ane
    case metal
    case cpu

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .auto: return L10n.ModelManager.Lab.Config.accelAuto
        case .ane: return L10n.ModelManager.Lab.Config.accelANE
        case .metal: return L10n.ModelManager.Lab.Config.accelMetal
        case .cpu: return L10n.ModelManager.Lab.Config.accelCPU
        }
    }
}

/// 端侧上下文缓存窗口规格选项
public enum ContextWindowOption: Int, CaseIterable, Identifiable, Sendable {
    case size2K = 2048
    case size4K = 4096
    case size8K = 8192
    case size32K = 32768

    public var id: Int { rawValue }

    public var displayLabel: String {
        switch self {
        case .size2K: return FeatureConstants.ContextWindowConstants.label2K
        case .size4K: return FeatureConstants.ContextWindowConstants.label4K
        case .size8K: return FeatureConstants.ContextWindowConstants.label8K
        case .size32K: return FeatureConstants.ContextWindowConstants.label32K
        }
    }

    public var estimatedKVMemoryMB: Int {
        switch self {
        case .size2K: return FeatureConstants.ContextWindowConstants.kvMemory2KMB
        case .size4K: return FeatureConstants.ContextWindowConstants.kvMemory4KMB
        case .size8K: return FeatureConstants.ContextWindowConstants.kvMemory8KMB
        case .size32K: return FeatureConstants.ContextWindowConstants.kvMemory32KMB
        }
    }
}

// MARK: - 参数配置 Sheet

extension ModelLabView {

    /// 参数配置底部弹出 Sheet
    var configurationSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.medium) {
                    // Model Configs / System Prompt 分段
                    Picker("", selection: $selectedConfigTab) {
                        Text(L10n.ModelManager.Lab.modelConfigs).tag(0)
                        Text(L10n.ModelManager.Lab.systemPrompt).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, DesignTokens.Spacing.medium)
                    .padding(.top, DesignTokens.Spacing.small)

                    if selectedConfigTab == 0 {
                        modelConfigsTabContent
                    } else {
                        systemPromptTabContent
                    }
                }
            }
            .navigationTitle(L10n.ModelManager.Lab.configurations)
            .appNavigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.ModelManager.Parameters.save) {
                        showConfigSheet = false
                    }
                    .foregroundStyle(Color.theme.cyan)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Model Configs 分段内容

    private var modelConfigsTabContent: some View {
        let useCase = labManager.selectedUseCase ?? .aiChat
        let isMultimodal = useCase == .askImage || useCase == .audioScribe
        let isAgent = useCase == .tinyGarden || useCase == .mobileActions
        
        return VStack(spacing: DesignTokens.Spacing.medium) {
            // 预设模板选择
            presetSelectorView
            
            // 提示文案展示
            if !labManager.paramTips.isEmpty {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.tiny) {
                    Image(systemName: DesignTokens.Icons.infoCircleFill)
                        .foregroundStyle(Color.theme.orange)
                    Text(labManager.paramTips)
                        .font(.system(size: DesignTokens.Typography.captionFontSize))
                        .foregroundStyle(Color.theme.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DesignTokens.Spacing.small)
                .background(Color.theme.orange.opacity(DesignTokens.Colors.subtleFillOpacity))
                .cornerRadius(DesignTokens.SystemRadius.small)
            }

            // Max Tokens
            paramSheetSlider(
                title: L10n.ModelManager.Parameters.maxTokens,
                value: Binding(
                    get: { Double(tempMaxTokens) },
                    set: { tempMaxTokens = Int($0) }
                ),
                range: 256...8192,
                step: 256,
                displayValue: "\(tempMaxTokens)"
            )

            if !isMultimodal {
                // TopK
                paramSheetSlider(
                    title: L10n.ModelManager.Parameters.topK,
                    value: Binding(
                        get: { Double(tempTopK) },
                        set: { tempTopK = Int($0) }
                    ),
                    range: 1...100,
                    step: 1,
                    displayValue: "\(tempTopK)",
                    isDisabled: isAgent
                )

                // TopP
                paramSheetSlider(
                    title: L10n.ModelManager.Parameters.topP,
                    value: $tempTopP,
                    range: 0.0...1.0,
                    step: 0.05,
                    displayValue: String(format: "%.2f", tempTopP),
                    isDisabled: isAgent
                )

                // Temperature
                paramSheetSlider(
                    title: L10n.ModelManager.Parameters.temperature,
                    value: isAgent ? .constant(0.0) : $tempTemperature,
                    range: 0.0...2.0,
                    step: 0.05,
                    displayValue: String(format: "%.2f", isAgent ? 0.0 : tempTemperature),
                    isDisabled: isAgent
                )
            }

            Divider().padding(.vertical, DesignTokens.Spacing.standardPadding)

            acceleratorSelector

            contextWindowSelector

            Divider().padding(.vertical, DesignTokens.Spacing.standardPadding)

            // 高级开关
            Toggle(L10n.ModelManager.Lab.enableThinking, isOn: $enableThinking)
                .tint(Color.theme.cyan)

            Toggle(L10n.ModelManager.Lab.enableSpeculativeDecoding, isOn: $enableSpeculativeDecoding)
                .tint(Color.theme.cyan)

            if enableSpeculativeDecoding {
                VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.tiny) {
                    HStack {
                        Text(L10n.ModelManager.Lab.Speculative.draftModel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(FeatureConstants.SpeculativeConstants.fallbackDraftModelId)
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.theme.cyan)
                    }

                    HStack(spacing: DesignTokens.Spacing.small) {
                        HStack(spacing: DesignTokens.SystemSpacing.atomic) {
                            Text(L10n.ModelManager.Lab.Speculative.acceptanceRate)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(L10n.ModelManager.Lab.Speculative.rateFormat(FeatureConstants.SpeculativeConstants.simulatedAcceptanceRatePercent))
                                .font(.caption2.bold())
                                .foregroundStyle(Color.theme.green)
                        }

                        Spacer()

                        HStack(spacing: DesignTokens.SystemSpacing.atomic) {
                            Text(L10n.ModelManager.Lab.Speculative.speedup)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(L10n.ModelManager.Lab.Speculative.speedupFormat(FeatureConstants.SpeculativeConstants.simulatedSpeedupMultiplier))
                                .font(.caption2.bold())
                                .foregroundStyle(Color.theme.cyan)
                        }
                    }
                    .padding(.top, DesignTokens.SystemSpacing.atomic)
                }
                .padding(DesignTokens.Spacing.small)
                .background(Color.theme.cyan.opacity(DesignTokens.Opacity.ghost))
                .cornerRadius(DesignTokens.SystemRadius.small)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.medium)
    }

    /// Auto / ANE / Metal 3 / CPU 推理加速器选择
    private var acceleratorSelector: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text(L10n.ModelManager.Lab.accelerator)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.Spacing.small) {
                ForEach(InferenceAccelerator.allCases) { accel in
                    let isSelected = selectedAccelerator == accel
                    Button {
                        HapticFeedback.shared.trigger(.selection)
                        selectedAccelerator = accel
                        useGPU = (accel != .cpu)
                    } label: {
                        Text(accel.displayTitle)
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.SystemSpacing.small)
                            .background(isSelected ? Color.theme.cyan : Color.appCard.opacity(DesignTokens.Opacity.subtle))
                            .foregroundStyle(isSelected ? .white : Color.secondary)
                            .cornerRadius(DesignTokens.SystemRadius.small)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Context Window 上下文缓存窗口选择器与 KV 显存预估
    private var contextWindowSelector: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack {
                Text(L10n.ModelManager.Lab.Config.contextWindow)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(L10n.ModelManager.Lab.Config.kvCacheFormat(selectedContextWindow.estimatedKVMemoryMB))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.theme.cyan)
            }

            HStack(spacing: DesignTokens.Spacing.small) {
                ForEach(ContextWindowOption.allCases) { option in
                    let isSelected = selectedContextWindow == option
                    Button {
                        HapticFeedback.shared.trigger(.selection)
                        selectedContextWindow = option
                    } label: {
                        Text(option.displayLabel)
                            .font(.caption.monospaced().bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.SystemSpacing.small)
                            .background(isSelected ? Color.theme.cyan : Color.appCard.opacity(DesignTokens.Opacity.subtle))
                            .foregroundStyle(isSelected ? .white : Color.secondary)
                            .cornerRadius(DesignTokens.SystemRadius.small)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - System Prompt 分段内容

    private var systemPromptTabContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            Text(L10n.ModelManager.Lab.systemPrompt)
                .font(.subheadline.bold())
                .foregroundStyle(.appText)

            TextEditor(text: $systemPromptText)
                .frame(minHeight: DesignSystem.Gallery.modalMaxWidth)
                .cardStyle(horizontalPadding: DesignTokens.Spacing.standardPadding, verticalPadding: DesignTokens.Spacing.standardPadding, backgroundOpacity: DesignTokens.Opacity.subtle, cornerRadius: DesignTokens.SystemRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small)
                        .stroke(Color.appBorder.opacity(DesignTokens.Opacity.glass), lineWidth: DesignTokens.SystemStroke.divider)
                )
                .font(.body)
                .foregroundStyle(Color.theme.text)
        }
        .padding(.horizontal, DesignTokens.Spacing.medium)
    }

    /// 参数配置 Sheet 中单行滑块组件
    func paramSheetSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        displayValue: String,
        isDisabled: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.small) {
            Text(title)
                .font(.subheadline)

            HStack(spacing: DesignTokens.Spacing.medium) {
                Slider(value: value, in: range, step: step)
                    .tint(Color.theme.cyan)
                    .disabled(isDisabled || !isCustomMode)

                Text(displayValue)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .frame(minWidth: DesignTokens.Spacing.Sidebar.backButtonWidth, alignment: .trailing)
                    .cardStyle(horizontalPadding: DesignTokens.Spacing.standardPadding, verticalPadding: DesignTokens.SystemSpacing.small, backgroundOpacity: DesignTokens.Opacity.subtle, cornerRadius: DesignTokens.Spacing.standardPadding)
            }
        }
    }

    // MARK: - 预设模板选择器

    var presetSelectorView: some View {
        PresetSelectorContainer(
            matchedPreset: matchedPreset,
            selectedBackground: Color.theme.cyan,
            unselectedBackground: Color.appCard.opacity(DesignTokens.Opacity.subtle),
            unselectedForeground: .secondary,
            customNudgeAction: {
                if let preset = matchedPreset {
                    tempTemperature = preset.parameters.temperature + FeatureConstants.InferenceParam.customNudgeDelta
                }
            },
            applyAction: { applyPreset($0) }
        )
    }
}

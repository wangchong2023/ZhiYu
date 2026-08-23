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

// MARK: - 参数配置 Sheet

extension ModelLabView {

    /// 参数配置底部弹出 Sheet
    var configurationSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.medium) {
                    // Model Configs / System Prompt 分段
                    Picker("", selection: $selectedConfigTab) {
                        Text(L10n.ModelManager.Lab.modelConfigs).tag(0)
                        Text(L10n.ModelManager.Lab.systemPrompt).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, DesignSystem.medium)
                    .padding(.top, DesignSystem.small)

                    if selectedConfigTab == 0 {
                        modelConfigsTabContent
                    } else {
                        systemPromptTabContent
                    }
                }
            }
            .navigationTitle(L10n.ModelManager.Lab.configurations)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.ModelManager.Parameters.save) {
                        showConfigSheet = false
                    }
                    .foregroundStyle(.cyan)
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
        
        return VStack(spacing: DesignSystem.medium) {
            // 预设模板选择
            presetSelectorView
            
            // 提示文案展示
            if !labManager.paramTips.isEmpty {
                HStack(alignment: .top, spacing: DesignSystem.tiny) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.theme.orange)
                    Text(labManager.paramTips)
                        .font(.system(size: DesignSystem.captionFontSize))
                        .foregroundStyle(Color.theme.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DesignSystem.small)
                .background(Color.theme.orange.opacity(DesignSystem.subtleFillOpacity))
                .cornerRadius(SystemRadius.small)
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

            Divider().padding(.vertical, DesignSystem.standardPadding)

            acceleratorSelector

            Divider().padding(.vertical, DesignSystem.standardPadding)

            // 高级开关
            Toggle(L10n.ModelManager.Lab.enableThinking, isOn: $enableThinking)
                .tint(.cyan)

            Toggle(L10n.ModelManager.Lab.enableSpeculativeDecoding, isOn: $enableSpeculativeDecoding)
                .tint(.cyan)
        }
        .padding(.horizontal, DesignSystem.medium)
    }

    /// CPU / GPU 加速器选择
    private var acceleratorSelector: some View {
        VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
            Text("Accelerator")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                Button(action: { useGPU = false }) {
                    Text("CPU")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.standardPadding + 4)
                        .background(useGPU ? Color.clear : Color.theme.cyan)
                        .foregroundStyle(useGPU ? Color.secondary : .white)
                }
                .buttonStyle(.plain)

                Button(action: { useGPU = true }) {
                    Text("GPU")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.standardPadding + 4)
                        .background(useGPU ? Color.theme.cyan : Color.clear)
                        .foregroundStyle(useGPU ? .white : Color.secondary)
                }
                .buttonStyle(.plain)
            }
            .background(Color.appCard.opacity(DesignSystem.Opacity.subtle))
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
        }
    }

    // MARK: - System Prompt 分段内容

    private var systemPromptTabContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            Text(L10n.ModelManager.Lab.systemPrompt)
                .font(.subheadline.bold())
                .foregroundStyle(.appText)

            TextEditor(text: $systemPromptText)
                .frame(minHeight: DesignSystem.Gallery.modalMaxWidth)
                .padding(DesignSystem.standardPadding)
                .background(Color.appCard.opacity(DesignSystem.Opacity.subtle))
                .cornerRadius(SystemRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: SystemRadius.small)
                        .stroke(Color.appBorder.opacity(DesignSystem.Opacity.glass), lineWidth: SystemStroke.divider)
                )
                .font(.body)
                .foregroundStyle(Color.theme.text)
        }
        .padding(.horizontal, DesignSystem.medium)
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
        VStack(alignment: .leading, spacing: DesignSystem.standardPadding / 2) {
            Text(title)
                .font(.subheadline)

            HStack(spacing: DesignSystem.medium) {
                Slider(value: value, in: range, step: step)
                    .tint(.cyan)
                    .disabled(isDisabled || !isCustomMode)

                Text(displayValue)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .frame(minWidth: Spacing.Sidebar.backButtonWidth, alignment: .trailing)
                    .padding(.horizontal, DesignSystem.standardPadding)
                    .padding(.vertical, DesignSystem.standardPadding / 2)
                    .background(Color.appCard.opacity(DesignSystem.Opacity.subtle))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardPadding))
            }
        }
    }

    // MARK: - 预设模板选择器

    var presetSelectorView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            Text(L10n.ModelManager.Parameters.presetTemplate)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.appText)

            HStack(spacing: DesignSystem.small) {
                ForEach(ParameterPreset.allCases, id: \.self) { preset in
                    presetButton(for: preset)
                }
                customButton
            }
        }
        .padding()
        .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius))
    }

    var customButton: some View {
        let isCustom = matchedPreset == nil
        return Button(action: {
            if let preset = matchedPreset {
                tempTemperature = preset.parameters.temperature + 0.01
            }
        }) {
            VStack(spacing: DesignSystem.tiny) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                Text(L10n.ModelManager.Parameters.custom)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.small)
            .background(isCustom ? Color.theme.cyan : Color.appCard.opacity(DesignSystem.Opacity.subtle))
            .foregroundStyle(isCustom ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
        }
        .buttonStyle(.plain)
        .disabled(isCustom)
    }

    func presetButton(for preset: ParameterPreset) -> some View {
        let isSelected = matchedPreset == preset
        return Button(action: { applyPreset(preset) }) {
            VStack(spacing: DesignSystem.tiny) {
                Image(systemName: preset.icon)
                    .font(.title3)
                Text(preset.displayName)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.small)
            .background(isSelected ? Color.theme.cyan : Color.appCard.opacity(DesignSystem.Opacity.subtle))
            .foregroundStyle(isSelected ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
        }
        .buttonStyle(.plain)
    }
}

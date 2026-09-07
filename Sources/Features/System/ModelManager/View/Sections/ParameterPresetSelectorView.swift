//
//  ParameterPresetSelectorView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：推理参数预设模板选择器（共享组件，消除 InferenceParametersView 与 ModelLabConfigSheet 的重复代码）。
//

import SwiftUI
import UFPCore

/// 推理预设模板选择器视图组件
struct ParameterPresetSelectorView: View {
    let matchedPreset: ParameterPreset?
    var tintColor: Color = .appAccent
    var unselectedBackground: Color = .appBackground
    var unselectedForeground: Color = .appText
    let onSelectPreset: (ParameterPreset) -> Void
    let onSelectCustom: () -> Void

    var body: some View {
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

    private var customButton: some View {
        let isCustom = matchedPreset == nil
        return Button(action: onSelectCustom) {
            VStack(spacing: DesignSystem.tiny) {
                Image(systemName: DesignSystem.Icons.sliderHorizontal)
                    .font(.title3)
                Text(L10n.ModelManager.Parameters.custom)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.small)
            .background(isCustom ? tintColor : unselectedBackground)
            .foregroundStyle(isCustom ? .white : unselectedForeground)
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
        }
        .buttonStyle(.plain)
        .disabled(isCustom)
    }

    private func presetButton(for preset: ParameterPreset) -> some View {
        let isSelected = matchedPreset == preset
        return Button(action: { onSelectPreset(preset) }) {
            VStack(spacing: DesignSystem.tiny) {
                Image(systemName: preset.icon)
                    .font(.title3)
                Text(preset.displayName)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.small)
            .background(isSelected ? tintColor : unselectedBackground)
            .foregroundStyle(isSelected ? .white : unselectedForeground)
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
        }
        .buttonStyle(.plain)
    }
}

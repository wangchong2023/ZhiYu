// 系统层级：[L3] 表现层
// 核心职责: 预设模板选择器共享容器，消除 InferenceParametersView 与 ModelLabConfigSheet 的 presetSelector + customButton + presetButton 重复

import SwiftUI

/// 预设模板选择器共享容器
///
/// 统一 `InferenceParametersView` 与 `ModelLabConfigSheet` 中几乎完全相同的
/// `presetSelector` / `customButton` / `presetButton` 三段视图，仅通过参数注入
/// 选中态颜色、未选中态背景与回调动作即可复用。
@MainActor
struct PresetSelectorContainer: View {
    /// 当前匹配的预设（nil 表示自定义模式）
    let matchedPreset: ParameterPreset?
    /// 选中态背景色
    let selectedBackground: Color
    /// 未选中态背景色
    let unselectedBackground: Color
    /// 未选中态前景色
    let unselectedForeground: Color
    /// 自定义按钮点击时的微调动作（从已锁定预设进入自定义）
    let customNudgeAction: () -> Void
    /// 选中某个预设时的应用动作
    let applyAction: (ParameterPreset) -> Void

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
        .cardStyle(
            horizontalPadding: DesignSystem.standardPadding,
            verticalPadding: DesignSystem.standardPadding
        )
    }

    /// 自定义模式按钮
    private var customButton: some View {
        let isCustom = matchedPreset == nil
        return Button(action: customNudgeAction) {
            VStack(spacing: DesignSystem.tiny) {
                Image(systemName: DesignSystem.Icons.sliderHorizontal)
                    .font(.title3)
                Text(L10n.ModelManager.Parameters.custom)
                    .font(.caption.weight(.medium))
            }
            .presetButtonStyle(
                isSelected: isCustom,
                selectedBackground: selectedBackground,
                unselectedBackground: unselectedBackground,
                unselectedForeground: unselectedForeground
            )
        }
        .buttonStyle(.plain)
        .disabled(isCustom)
    }

    /// 预设按钮
    private func presetButton(for preset: ParameterPreset) -> some View {
        Button(action: { applyAction(preset) }) {
            PresetButtonContent(preset: preset)
                .presetButtonStyle(
                    isSelected: matchedPreset == preset,
                    selectedBackground: selectedBackground,
                    unselectedBackground: unselectedBackground,
                    unselectedForeground: unselectedForeground
                )
        }
        .buttonStyle(.plain)
    }
}

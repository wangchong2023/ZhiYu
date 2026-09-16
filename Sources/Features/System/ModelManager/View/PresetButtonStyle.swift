// 系统层级：[L3] 表现层
// 核心职责: 预设按钮共享样式修饰符，消除 InferenceParametersView 与 ModelLabConfigSheet 的重复

import SwiftUI

/// 预设按钮样式修饰符，消除跨文件的 frame+padding+background+foregroundStyle+clipShape 链
struct PresetButtonStyle: ViewModifier {
    let isSelected: Bool
    let selectedBackground: Color
    let unselectedBackground: Color
    let selectedForeground: Color
    let unselectedForeground: Color

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.small)
            .background(isSelected ? selectedBackground : unselectedBackground)
            .foregroundStyle(isSelected ? selectedForeground : unselectedForeground)
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
    }
}

extension View {
    /// 应用预设按钮样式
    func presetButtonStyle(
        isSelected: Bool,
        selectedBackground: Color = Color.appAccent,
        unselectedBackground: Color = Color.appBackground,
        selectedForeground: Color = .white,
        unselectedForeground: Color = .appText
    ) -> some View {
        modifier(
            PresetButtonStyle(
                isSelected: isSelected,
                selectedBackground: selectedBackground,
                unselectedBackground: unselectedBackground,
                selectedForeground: selectedForeground,
                unselectedForeground: unselectedForeground
            )
        )
    }
}

/// 预设按钮内容视图，消除 InferenceParametersView 与 ModelLabConfigSheet 的重复
struct PresetButtonContent: View {
    let preset: ParameterPreset

    var body: some View {
        VStack(spacing: DesignSystem.tiny) {
            Image(systemName: preset.icon)
                .font(.title3)
            Text(preset.displayName)
                .font(.caption.weight(.medium))
        }
    }
}

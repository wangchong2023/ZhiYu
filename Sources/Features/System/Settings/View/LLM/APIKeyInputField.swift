// 系统层级: L3 表现层
// 核心职责: API Key 输入组件，消除 LLMSettingsView 中 TextField/SecureField + eye toggle 的重复

import SwiftUI

/// API Key 输入组件（带显隐切换与校验提示）
///
/// 消除 `LLMSettingsView` 中重复的
/// `if showAPIKey { TextField(...) } else { SecureField(...) }` + eye toggle 模式。
struct APIKeyInputField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var isShown: Bool
    let isValid: Bool

    var body: some View {
        HStack {
            Group {
                if isShown {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .foregroundStyle(.appText)
            .font(.system(.body, design: .monospaced))
            Button(action: { isShown.toggle() }) {
                Image(systemName: isShown ? DesignSystem.Icons.eyeSlash : DesignSystem.Icons.eye)
                    .foregroundStyle(.appSecondary)
            }
        }
        .padding()
        .background(Color.appCard.opacity(DesignSystem.Opacity.prominent))
        .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: SystemRadius.small)
                .stroke(
                    isValid || text.isEmpty
                        ? Color.appBorder.opacity(DesignSystem.Opacity.prominent)
                        : Color.appAlert.opacity(DesignSystem.Opacity.prominent),
                    lineWidth: SystemStroke.divider
                )
        )
    }
}

// 系统层级：[L3] 表现层
// 核心职责：信息图标行组件，消除 CollabInfoRow 与 SyncInfoRow 的重复

import SwiftUI

/// 信息图标行组件（图标 + 文本）
///
/// 消除 `CollabInfoRow` 与 `SyncInfoRow` 中几乎完全相同的
/// `HStack { Image(systemName:); Text() }` 模式。
/// 通过 `alignment`、`spacing`、`iconColor`、`textColor`、`iconWidth` 参数注入差异化样式。
struct InfoIconRow: View {
    let icon: String
    let text: String
    let alignment: VerticalAlignment
    let spacing: CGFloat
    let iconColor: Color
    let textColor: Color
    let iconWidth: CGFloat?

    init(
        icon: String,
        text: String,
        alignment: VerticalAlignment = .center,
        spacing: CGFloat = DesignSystem.CompositeRow.spacing,
        iconColor: Color = .appAccent,
        textColor: Color = .appText,
        iconWidth: CGFloat? = ComponentSpacing.section
    ) {
        self.icon = icon
        self.text = text
        self.alignment = alignment
        self.spacing = spacing
        self.iconColor = iconColor
        self.textColor = textColor
        self.iconWidth = iconWidth
    }

    var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor)
                .frame(width: iconWidth ?? 0)
            Text(text)
                .font(.caption)
                .foregroundStyle(textColor)
        }
    }
}

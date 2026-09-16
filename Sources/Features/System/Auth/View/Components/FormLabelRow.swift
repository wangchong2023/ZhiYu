// 系统层级：[L3] 表现层
// 核心职责: 表单标签行共享组件，消除 UserProfileView 中重复的 HStack { Image + Text } 表单行模式

import SwiftUI

/// 表单标签行组件（图标 + 标题文本）
///
/// 消除 `UserProfileView` 中重复出现的
/// `HStack(spacing: SystemSpacing.element) { Image(...).foregroundStyle(...); Text(...).font(.caption.bold()).foregroundStyle(.appSecondary) }` 模式。
struct FormLabelRow: View {
    let icon: String
    let title: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: SystemSpacing.element) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.appSecondary)
        }
    }
}

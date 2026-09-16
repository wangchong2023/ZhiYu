// 系统层级: L3 表现层
// 核心职责: 指标瓦片组件，消除 PluginStatsSection.statCard 与 UserProfileView.metricItem 的重复

import SwiftUI

/// 指标瓦片组件（图标 + 标题 + 数值）
///
/// 消除 `PluginStatsSection.statCard` 与 `UserProfileView.metricItem` 中重复的
/// `VStack { HStack { Image + Text }; Text(value) }` + 容器样式模式。
struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    let valueColor: Color
    let containerOpacity: Double
    let cornerRadius: CGFloat

    init(
        title: String,
        value: String,
        icon: String,
        iconColor: Color,
        valueColor: Color = .appText,
        containerOpacity: Double = DesignSystem.softOpacity,
        cornerRadius: CGFloat = SystemRadius.card
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.iconColor = iconColor
        self.valueColor = valueColor
        self.containerOpacity = containerOpacity
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
            HStack(spacing: DesignSystem.tiny) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.appSecondary)
            }
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.small)
        .background(Color.appCard.opacity(containerOpacity))
        .cornerRadius(cornerRadius)
    }
}

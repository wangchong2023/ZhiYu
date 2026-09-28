//
//  PluginStatsSection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：系统设置：插件资源消耗大盘、Donut 饼图监控、运行时状态诊断（完全消除硬编码设计）。
//

import SwiftUI
import Charts
import Dependencies
import UFPDesignSystem

struct PluginStatsSection: View {
    @Dependency(\.pluginRegistry) var registry

    var body: some View {
        StandardSection(title: L10n.Plugin.Stats.resourceUsage) {
            if registry.pluginResourceUsage.isEmpty {
                AppEmptyState.simple(icon: "puzzlepiece.extension", title: L10n.Plugin.Stats.noUsage)
                    .padding()
            } else {
                let sortedUsage = registry.pluginResourceUsage.sorted { $0.value.totalExecutionTime > $1.value.totalExecutionTime }
                let totalTime = sortedUsage.map(\.value.totalExecutionTime).reduce(0, +)

                VStack(spacing: DesignTokens.Spacing.medium) {
                    // 顶部统计卡片，让画面更显饱满与专业
                    HStack(spacing: DesignTokens.Spacing.medium) {
                        MetricTile(
                            title: L10n.Plugin.Stats.enabledCount,
                            value: "\(registry.plugins.count)",
                            icon: DesignTokens.Icons.puzzlepieceExtensionFill,
                            iconColor: Color.theme.blue,
                            valueColor: .appText,
                            containerOpacity: DesignTokens.Opacity.dim,
                            cornerRadius: DesignTokens.Spacing.mediumRadius
                        )
                        MetricTile(
                            title: L10n.Plugin.Stats.activeCount,
                            value: "\(registry.pluginResourceUsage.filter { $0.value.status == .active }.count)",
                            icon: DesignTokens.Icons.playCircleFill,
                            iconColor: Color.theme.green,
                            valueColor: .appText,
                            containerOpacity: DesignTokens.Opacity.dim,
                            cornerRadius: DesignTokens.Spacing.mediumRadius
                        )
                    }
                    .padding(.horizontal, DesignTokens.Spacing.small)

                    // Donut 环形占比图表
                    if totalTime > 0 {
                        VStack(spacing: DesignTokens.Spacing.small) {
                            Chart(sortedUsage, id: \.key) { id, usage in
                                SectorMark(
                                    angle: .value("Time", usage.totalExecutionTime),
                                    innerRadius: .ratio(0.65),
                                    angularInset: DesignTokens.Spacing.atomic
                                )
                                .foregroundStyle(by: .value("Plugin", displayName(for: id)))
                                .cornerRadius(DesignTokens.Spacing.microRadius)
                            }
                            .frame(height: DesignTokens.Metrics.chartHeight)
                            .padding(.top, DesignTokens.Spacing.small)

                            Text(L10n.Plugin.Stats.totalExecutionTime(String(format: "%.3fs", totalTime)))
                                .font(.system(size: DesignTokens.Typography.captionFontSize, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.appSecondary)
                        }
                        .padding(.vertical, DesignTokens.Spacing.small)
                        .background(Color.appCard.opacity(DesignTokens.Opacity.subtle))
                        .cornerRadius(DesignTokens.SystemRadius.small)
                    }

                    // 插件列表明细
                    VStack(spacing: 0) {
                        ForEach(Array(sortedUsage.enumerated()), id: \.offset) { index, item in
                            let (id, usage) = item
                            let percentage = totalTime > 0 ? usage.totalExecutionTime / totalTime : 0.0

                            HStack(spacing: DesignTokens.Spacing.medium) {
                                // 插件专有动态或本地缓存图标
                                pluginIconView(for: id)

                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                                    HStack(spacing: DesignTokens.Spacing.small) {
                                        // 动态语言匹配的插件显示名称
                                        Text(displayName(for: id))
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.appText)

                                        // 彩点状态指示器
                                        Circle()
                                            .fill(statusColor(for: usage.status))
                                            .frame(width: DesignTokens.SystemSpacing.small, height: DesignTokens.SystemSpacing.small)
                                    }

                                    // 自定义微缩进度条表示总时间占比 (利用标准化 progressHeight 消除硬编码)
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.appBorder.opacity(DesignTokens.Opacity.subtle))
                                                .frame(height: DesignTokens.Metrics.progressHeight)

                                            Capsule()
                                                .fill(pluginColor(for: id))
                                                .frame(width: geo.size.width * CGFloat(percentage), height: DesignTokens.Metrics.progressHeight)
                                        }
                                    }
                                    .frame(height: DesignTokens.Metrics.progressHeight)
                                    .padding(.top, DesignTokens.Spacing.atomic)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: DesignTokens.Spacing.tiny) {
                                    // 耗时数值与占比 (添加 CPU 与 占比 的辅助文本)
                                    HStack(spacing: DesignTokens.SystemSpacing.atomic) {
                                        Text(L10n.Plugin.Stats.cpu)
                                            .font(.system(size: DesignTokens.Typography.microFontSize))
                                            .foregroundStyle(.appSecondary)
                                        Text(String(format: "%.2fs", usage.totalExecutionTime))
                                            .font(.system(.footnote, design: .monospaced).weight(.bold))
                                            .foregroundStyle(usage.status == .suspended ? Color.theme.red : .appText)
                                    }

                                    HStack(spacing: DesignTokens.SystemSpacing.atomic) {
                                        Text(L10n.Plugin.Stats.ratio)
                                            .font(.system(size: DesignTokens.Typography.microFontSize))
                                            .foregroundStyle(.appSecondary)
                                        Text(String(format: "%.1f%%", percentage * FeatureConstants.PercentageBase.full))
                                            .font(.system(size: DesignTokens.SystemFontSize.micro, design: .monospaced))
                                            .foregroundStyle(.appSecondary)
                                    }
                                }
                            }
                            .padding(.vertical, DesignTokens.SystemSpacing.element)

                            if index < sortedUsage.count - 1 {
                                Divider().opacity(DesignTokens.Opacity.shadow)
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.small)
                }
            }
        }
    }

    // MARK: - 辅助映射函数 (完全去业务硬编码)

    /// 动态获取当前插件实体的本地化显示名称
    private func displayName(for pluginID: String) -> String {
        if let plugin = registry.plugins.first(where: { $0.manifest.id == pluginID }) {
            return plugin.manifest.name
        }
        // 如果插件还没加载完成，做基础裁剪提取
        return pluginID.replacingOccurrences(of: PluginConstants.IDPrefix.local, with: "")
                       .replacingOccurrences(of: PluginConstants.IDPrefix.remote, with: "")
                       .replacingOccurrences(of: PluginConstants.IDPrefix.base, with: "")
                       .capitalized
    }

    /// 动态加载插件缓存的物理图标，无本地缓存时回退至动态主题色扩展插槽默认图标
    @ViewBuilder
    private func pluginIconView(for pluginID: String) -> some View {
        if let iconURL = registry.iconURL(for: pluginID),
           let data = try? Data(contentsOf: iconURL),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: DesignTokens.IconSize.large, height: DesignTokens.IconSize.large)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small))
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small).stroke(Color.appBorder.opacity(DesignTokens.Opacity.subtle), lineWidth: DesignTokens.SystemStroke.divider))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small, style: .continuous)
                    .fill(pluginColor(for: pluginID).opacity(DesignTokens.Opacity.subtle))
                    .frame(width: DesignTokens.IconSize.large, height: DesignTokens.IconSize.large)

                Image(systemName: DesignTokens.Icons.puzzlepieceExtensionFill)
                    .font(.title3)
                    .foregroundStyle(pluginColor(for: pluginID))
            }
        }
    }

    /// 基于哈希的自适应离散颜色生成器，保证新插件接入时大盘颜色的区分性且彻底去除写死关联
    private func pluginColor(for pluginID: String) -> Color {
        let colors: [Color] = [Color.theme.blue, Color.theme.purple, Color.theme.teal, Color.theme.green, Color.theme.orange, Color.theme.pink, Color.theme.indigo, Color.theme.mint]
        let hash = abs(pluginID.hashValue)
        return colors[hash % colors.count]
    }

    private func statusColor(for status: PluginRuntime.ResourceUsage.Status) -> Color {
        switch status {
        case .active: return Color.theme.green
        case .throttled: return Color.theme.orange
        case .suspended: return Color.theme.red
        }
    }

}

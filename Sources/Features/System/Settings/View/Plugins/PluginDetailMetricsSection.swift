//
//  PluginDetailMetricsSection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：App Store 风格的快捷指标横向滚轴栏，展示评分星级、安全检测认证、开发者信息与
//  最低系统兼容性要求。
//

import SwiftUI

/// 插件指标区常量
private enum PluginMetricsConstants {
    /// 指标栏高度 (iconDisplay + giant = 72)
    static let barHeight: CGFloat = 72
}

// MARK: - App Store 风格快捷指标滚轴

extension PluginDetailView {

    var appStoreMetricsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // 卡片 1: 评分与星级
                let reviewLabel = plugin.reviewCount.map { L10n.Plugin.Detail.reviewCount($0) } ?? L10n.Plugin.Stats.rating
                metricCard(
                    title: String(format: "%.1f ★", plugin.rating),
                    subtitle: reviewLabel
                )

                metricDivider

                // 卡片 2: 安全检测认证 (沙盒审计通过)
                metricCard(
                    title: L10n.Plugin.Detail.securePassed,
                    subtitle: L10n.Plugin.Detail.secureLabel,
                    icon: DesignSystem.Icons.lockShieldFill,
                    iconColor: Color.theme.green
                )

                metricDivider

                // 卡片 3: 开发者
                metricCard(
                    title: plugin.author,
                    subtitle: L10n.Plugin.Detail.author
                )

                metricDivider

                // 卡片 4: 最低系统要求
                let compatVal = plugin.minAppVersion.map { "iOS \($0)+" } ?? L10n.Plugin.Detail.allPlatforms
                metricCard(
                    title: compatVal,
                    subtitle: L10n.Plugin.Detail.compatibilityTitle
                )
            }
            .padding(.horizontal, DesignSystem.small)
        }
        .frame(height: PluginMetricsConstants.barHeight)
    }

    /// 单个快捷指标项卡片渲染
    func metricCard(title: String, subtitle: String, icon: String? = nil, iconColor: Color = .secondary) -> some View {
        VStack(spacing: DesignSystem.tiny) {
            Text(subtitle)
                .font(.system(size: SystemFontSize.micro, weight: .bold)) // Dynamic Type
                .foregroundStyle(.appSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let icon = icon {
                HStack(spacing: SystemSpacing.tiny) {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.caption.bold())
                    Text(title)
                        .font(.headline.bold())
                        .foregroundStyle(.appText)
                }
            } else {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(.appText)
                    .lineLimit(1)
            }
        }
        .frame(width: ComponentSpacing.metricChipWidth, height: ComponentSpacing.buttonHeight)
    }

    var metricDivider: some View {
        Divider()
            .frame(height: Spacing.huge)
            .padding(.horizontal, DesignSystem.medium)
    }
}

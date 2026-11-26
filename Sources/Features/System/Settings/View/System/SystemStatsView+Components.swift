//
//  SystemStatsView+Components.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / 系统统计子视图扩展
//  核心职责：承载 SystemStatsView 的存储环形图、图例、时延指标卡片、资产网格项
//           与统计图表分区组件，按单一职责与主容器解耦。
//

import SwiftUI
import Charts
import UFPDesignSystem

extension SystemStatsView {

    // MARK: - 辅助组件

    var chartContainer: some View {
        ZStack {
            Chart(coordinator.storageCategories) { category in
                SectorMark(
                    angle: .value("Size", Double(category.value)),
                    innerRadius: .ratio(FeatureConstants.TaskCenterLayout.donutInnerRadiusRatio),
                    angularInset: 3
                )
                .cornerRadius(6)
                .foregroundStyle(category.color)
            }
            .chartLegend(.hidden)
            .frame(height: DesignTokens.ComponentSpacing.chartHeight)

            VStack(spacing: DesignTokens.Spacing.tiny) {
                Text(coordinator.formatBytes(coordinator.totalStorage))
                    .font(.system(size: DesignTokens.SystemFontSize.title, weight: .bold, design: .rounded))
                    .foregroundStyle(.appAccent)
                Text(L10n.Dashboard.totalStorage)
                    .font(.system(size: DesignTokens.Typography.microFontSize, weight: .black))
                    .foregroundStyle(.appSecondary)
                    .kerning(DesignTokens.SystemSpacing.divider)
                    .textCase(.uppercase)
            }
        }
    }

    var legendContainer: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            ForEach(coordinator.storageCategories) { category in
                HStack(spacing: DesignTokens.Spacing.tiny) {
                    Circle()
                        .fill(category.color)
                        .frame(width: DesignTokens.SystemSpacing.tiny, height: DesignTokens.SystemSpacing.tiny)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(category.label)
                            .font(DesignTokens.Typography.caption2Font)
                            .foregroundStyle(.appText)
                            .lineLimit(1)
                        HStack(spacing: DesignTokens.Spacing.tiny) {
                            Text(coordinator.formatBytes(category.value))
                            let percent = coordinator.totalStorage > 0 ? Int(Double(category.value) / Double(coordinator.totalStorage) * Double(FeatureConstants.PercentageBase.fullInt)) : 0
                            Text("(\(percent)%)")
                        }
                        .font(.system(size: DesignTokens.Typography.microFontSize))
                        .foregroundStyle(.appSecondary)
                    }
                }
            }
        }
    }

    // MARK: - 时延卡片辅助

    func latencySubValue(label: String, value: String) -> some View {
        VStack(alignment: .center, spacing: DesignTokens.Spacing.tiny) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.appSecondary)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.appText)
        }
        .frame(maxWidth: .infinity)
    }

    var divider: some View {
        Divider()
            .frame(height: DesignTokens.IconSize.micro)
            .padding(.horizontal, DesignTokens.Spacing.tiny)
    }

    func assetCategoryGridItem(title: String, count: Int, size: Int64, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
            Text(title)
                .font(.system(size: DesignTokens.SystemFontSize.micro, weight: .bold)) // Dynamic Type
                .foregroundStyle(.secondary)

            Text(L10n.Dashboard.stats.itemsCount(count))
                .font(.subheadline.bold())
                .foregroundStyle(.appText)

            Text(coordinator.formatBytes(size))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(DesignTokens.Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard.opacity(DesignTokens.Opacity.subtle))
        .cornerRadius(DesignTokens.SystemRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small)
                .stroke(color.opacity(DesignTokens.Opacity.shadow), lineWidth: DesignTokens.SystemStroke.divider)
        )
    }

    /// 百分比文本，消除存储分类与数据库条目的重复
    func percentText(_ percent: Int) -> some View {
        Text("\(percent)%")
            .font(.system(size: DesignTokens.Typography.microFontSize, design: .rounded))
            .foregroundStyle(.appSecondary)
    }

    /// 统计卡片标题行，消除 API 请求与 Token 消耗卡片的重复
    func statsCardHeader(value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.small) {
            Text(value)
                .font(.system(size: DesignTokens.Typography.titleFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.appText)
            Text(label)
                .font(.caption)
                .foregroundStyle(.appSecondary)
        }
    }

    /// 统计图表卡片，消除 API 请求与 Token 消耗卡片的重复结构
    func statsChartSection(
        title: String,
        totalValue: Int,
        valueLabel: String,
        chartType: ChartView.ChartType
    ) -> some View {
        StandardSection(title: title) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.small) {
                    statsCardHeader(value: "\(totalValue)", label: valueLabel)
                }

                ChartView(stats: coordinator.dailyStats, type: chartType)
                    .frame(height: DesignTokens.ComponentSpacing.chartHeight)
            }
            .padding(DesignTokens.Spacing.medium)
        }
    }
}

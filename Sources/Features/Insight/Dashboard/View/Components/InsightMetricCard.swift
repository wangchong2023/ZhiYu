//
//  InsightMetricCard.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Insight 模块通用指标卡片，统一 MetricBox / StatBox / InsightStat / metricCard 四处重复的
//  "圆形图标 + 数值 + 标签" 卡片布局。
//

import SwiftUI

/// [L3] 表现层：Insight 模块通用指标卡片
///
/// 统一封装圆形图标背景、数值排版、标签文案与卡片容器样式，
/// 通过 `layout` 参数适配紧凑型（Dashboard）与展开型（Lint）两种排版。
struct InsightMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var unit: String?
    var trend: String?

    /// 卡片排版模式
    enum Layout {
        /// Dashboard 模式：图标在左上，数值在下方，带 trend 胶囊
        case dashboard
        /// Lint 模式：图标在左上，数值在下方，无 trend
        case lint
        /// Vault 模式：标签在上，数值在下，紧凑垂直布局
        case vault
        /// Weekly 模式：图标在左，数值+标签在右，横向布局
        case weekly
    }

    let layout: Layout

    init(
        title: String,
        value: String,
        icon: String,
        color: Color,
        unit: String? = nil,
        trend: String? = nil,
        layout: Layout = .lint
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.unit = unit
        self.trend = trend
        self.layout = layout
    }

    var body: some View {
        switch layout {
        case .dashboard:
            dashboardLayout
        case .lint:
            lintLayout
        case .vault:
            vaultLayout
        case .weekly:
            weeklyLayout
        }
    }

    // MARK: - Dashboard 布局

    private var dashboardLayout: some View {
        VStack(alignment: .leading, spacing: SystemSpacing.contentMedium) {
            HStack {
                iconCircle(size: DesignSystem.Timeline.indicatorSize, iconFontSize: DesignSystem.subheadlineFontSize)
                Spacer()
                if let trend {
                    trendCapsule(trend)
                }
            }

            metricTitleAndValue(valueFont: .system(size: DesignSystem.Metrics.heroValueSize, weight: .bold, design: .rounded), showUnit: true)
        }
        .padding(DesignSystem.standardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(DesignSystem.Opacity.prominent))
        .background(
            ZStack {
                Color.appCard.opacity(DesignSystem.Opacity.disabled)
                LinearGradient(
                    colors: [color.opacity(DesignSystem.Opacity.subtle), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.dashboardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.dashboardRadius)
                .stroke(
                    LinearGradient(
                        colors: [.appBorder.opacity(DesignSystem.Opacity.dim), .appBorder.opacity(DesignSystem.Opacity.subtle)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: DesignSystem.borderWidth
                )
        )
        .appStandardShadow()
    }

    // MARK: - Lint 布局

    private var lintLayout: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack {
                iconCircle(size: ComponentSpacing.huge, iconFontSize: DesignSystem.subheadlineFontSize)
                Spacer()
            }

            metricTitleAndValue(valueFont: .system(size: DesignSystem.displayFontSize, weight: .bold, design: .rounded), showUnit: false)
        }
        .padding(DesignSystem.standardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appContainer(background: Color.appCard, cornerRadius: DesignSystem.Metrics.dashboardRadius, padding: false)
        .shadow(color: .primary.opacity(DesignSystem.Opacity.faint), radius: SystemSpacing.medium, x: 0, y: SystemSpacing.small)
    }

    // MARK: - Vault 布局

    private var vaultLayout: some View {
        VStack(spacing: DesignSystem.tiny) {
            Text(title)
                .font(.system(size: DesignSystem.caption2FontSize, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: DesignSystem.title2FontSize, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.medium)
        .appContainer(background: Color.appCard.opacity(DesignSystem.surfaceOpacity), padding: false)
    }

    // MARK: - Weekly 布局

    private var weeklyLayout: some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Metrics.iconBoxSize / 2, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: ComponentSpacing.buttonHeight, height: ComponentSpacing.buttonHeight)
                .background(
                    Circle()
                        .fill(color.opacity(SystemOpacity.glass))
                        .overlay(Circle().stroke(color.opacity(DesignSystem.disabledOpacity), lineWidth: DesignSystem.borderWidth))
                )

            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.appText)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
            }
        }
    }

    // MARK: - 共享子组件

    /// 标题 + 数值（+可选单位）的共享布局
    @ViewBuilder
    private func metricTitleAndValue(valueFont: Font, showUnit: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.atomic) {
            Text(title)
                .font(.system(size: DesignSystem.captionFontSize, weight: .medium))
                .foregroundColor(.appSecondary)

            if showUnit {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.tiny) {
                    Text(value)
                        .font(valueFont)
                        .foregroundColor(.appText)

                    if let unit {
                        Text(unit)
                            .font(.caption2)
                            .foregroundColor(.appSecondary)
                    }
                }
            } else {
                Text(value)
                    .font(valueFont)
                    .foregroundColor(.appText)
            }
        }
    }

    @ViewBuilder
    private func iconCircle(size: CGFloat, iconFontSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(DesignSystem.glassOpacity))
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: iconFontSize, weight: .bold))
                .foregroundColor(color)
        }
    }

    @ViewBuilder
    private func trendCapsule(_ trend: String) -> some View {
        HStack(spacing: DesignSystem.atomic) {
            Image(systemName: DesignSystem.Icons.arrowUpRightSimple)
            Text(trend)
        }
        .font(.system(size: DesignSystem.caption2FontSize, weight: .bold, design: .rounded))
        .foregroundStyle(Color.theme.green)
        .padding(.horizontal, DesignSystem.Chip.horizontalPadding)
        .padding(.vertical, DesignSystem.Chip.verticalPadding)
        .background(Color.theme.green.opacity(DesignSystem.glassOpacity))
        .clipShape(Capsule())
    }
}

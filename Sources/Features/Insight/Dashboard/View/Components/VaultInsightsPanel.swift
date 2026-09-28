//
//  VaultInsightsPanel.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：仪表盘：页面列表、知识统计、每周洞察、回链视图。
//
import SwiftUI
import UFPDesignSystem

/// 笔记本数据洞察面板
struct VaultInsightsPanel: View {
    @Environment(AppStore.self) var store
    @Environment(VaultService.self) var vaultService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.huge) {
                // 1. 头部标题
                HStack {
                    Label(
                        vaultService.currentVault?.name ?? L10n.Vault.noSelection,
                        systemImage: vaultService.currentVault == nil ? DesignTokens.Icons.stackFill : DesignTokens.Icons.chartBar
                    )
                    .font(.headline)
                    Spacer()
                    PanelCloseButton()
                }
                .padding(.bottom, DesignTokens.Spacing.medium)
                
                // 2. 核心统计指标
                HStack(spacing: DesignTokens.Spacing.standardPadding) {
                    InsightMetricCard(title: L10n.Dashboard.stats.short.pages, value: "\(store.totalPages)", icon: DesignTokens.Icons.documentFill, color: .appAccent, layout: .vault)
                    InsightMetricCard(title: L10n.Dashboard.stats.short.new, value: FeatureConstants.StatDisplayValue.newPagesDelta, icon: DesignTokens.Icons.plus, color: Color.theme.green, layout: .vault)
                    InsightMetricCard(title: L10n.Dashboard.stats.short.ref, value: FeatureConstants.StatDisplayValue.refPercent, icon: DesignTokens.Icons.link, color: Color.theme.orange, layout: .vault)
                }
                
                // 3. 模拟图表：分类分布
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    Text(L10n.Dashboard.stats.categoryDistribution)
                        .font(.system(size: DesignTokens.Typography.subheadlineFontSize, weight: .bold))
                    
                    HStack(alignment: .bottom, spacing: DesignTokens.Spacing.medium) {
                        // Bug #104 修复：硬编码 0.6/0.8/0.4/0.2/0.05 改用 FeatureConstants.VaultInsightsBarRatio
                        BarItem(label: L10n.Dashboard.stats.short.entity, value: FeatureConstants.VaultInsightsBarRatio.entity, color: .appEntity)
                        BarItem(label: L10n.Dashboard.stats.short.concept, value: FeatureConstants.VaultInsightsBarRatio.concept, color: .appConcept)
                        BarItem(label: L10n.Dashboard.stats.short.source, value: FeatureConstants.VaultInsightsBarRatio.source, color: .appSource)
                        BarItem(label: L10n.Dashboard.stats.short.comparison, value: FeatureConstants.VaultInsightsBarRatio.comparison, color: .appComparison)
                        BarItem(label: L10n.Dashboard.stats.short.raw, value: FeatureConstants.VaultInsightsBarRatio.raw, color: Color.theme.gray)
                    }
                    .frame(height: DesignTokens.Metrics.chartHeight)
                }
                .appContainer(background: Color.appCard.opacity(DesignTokens.Colors.Opacity.surfaceOpacity), padding: true)
                
                // 4. 模拟图表：增长曲线 (极简)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    Text(L10n.Dashboard.stats.knowledgeGrowth)
                        .font(.system(size: DesignTokens.Typography.subheadlineFontSize, weight: .bold))
                    
                    ChartLinePlaceholder()
                        .frame(height: DesignTokens.Metrics.chartHeight)
                        .foregroundStyle(.appAccent.gradient)
                }
                .appContainer(background: Color.appCard.opacity(DesignTokens.Colors.Opacity.surfaceOpacity), padding: true)
                
                Spacer(minLength: DesignTokens.Spacing.huge)
            }
            .padding(DesignTokens.Spacing.huge)
        }
        .presentationDetents([.large])
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Subviews
private struct BarItem: View {
    let label: String
    let value: CGFloat
    let color: Color
    
    var body: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: DesignTokens.Radius.micro)
                .fill(color.gradient)
                .frame(height: DesignTokens.Metrics.chartHeight * value)
            Text(label)
                .font(.system(size: DesignTokens.Typography.caption2FontSize))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ChartLinePlaceholder: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: geo.size.height * FeatureConstants.VaultChartPlaceholder.startHeightRatio))
                path.addCurve(to: CGPoint(x: geo.size.width, y: geo.size.height * FeatureConstants.VaultChartPlaceholder.endHeightRatio),
                             control1: CGPoint(x: geo.size.width * FeatureConstants.VaultChartPlaceholder.control1WidthRatio, y: geo.size.height * FeatureConstants.VaultChartPlaceholder.control1HeightRatio),
                             control2: CGPoint(x: geo.size.width * FeatureConstants.VaultChartPlaceholder.control2WidthRatio, y: geo.size.height * FeatureConstants.VaultChartPlaceholder.control2HeightRatio))
            }
            .stroke(lineWidth: DesignSystem.Decorator.accentLineWidth)
        }
    }
}

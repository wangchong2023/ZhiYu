//
//  KnowledgeDashboardView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 KnowledgeDashboard 界面的 UI 视图层组件。
//
import SwiftUI
import Dependencies
import UFPDesignSystem

struct KnowledgeDashboardView: View {
    @Dependency(\.toastService) private var toastManager
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // 使用协调器管理状态与交互
    @State private var coordinator = DashboardCoordinator()
    @State private var showDensityInfo = false
    
    var body: some View {
        @Bindable var coordinator = coordinator
        ZStack(alignment: .top) {
            // 1. 方案 D 沉浸式高级背景同步
            ZStack {
                Color.theme.black.overlay(themeManager.pageBackground().opacity(DesignTokens.Opacity.disabled))
                MeshGradientView()
                    .blur(radius: 80)
            }
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.huge) {
                    AIProcessingStatusBanner()
                        .padding(.bottom, -DesignTokens.Spacing.standardPadding)
                        
                    metricSection
                    densityChartSection
                    dailyInsightsSection
                    hotTopicsSection
                }
                .padding()
                .padding(.bottom, DesignTokens.ComponentSpacing.chartHalfHeight)
            }
            .scrollIndicators(.hidden)
            
        }
        .appTabToolbar(title: L10n.Common.Sidebar.dashboard, showVaultBadge: false)
        .task(id: store.pages.count) {
            guard !Task.isCancelled else { return }
            await coordinator.refreshAll(store: store)
        }
    }
    
    // MARK: - Sub-Sections
    
    private var metricSection: some View {
        // 1. 核心指标概览
        HStack(spacing: DesignSystem.Grid.standardSpacing) {
            InsightMetricCard(
                title: L10n.Dashboard.totalPages,
                value: "\(store.pages.count)",
                icon: DesignTokens.Icons.documentFill,
                color: .appAccent,
                unit: L10n.Dashboard.pageListPages,
                trend: nil,
                layout: .dashboard
            )
            InsightMetricCard(
                title: L10n.Dashboard.totalLinks,
                value: "\(coordinator.totalLinks)",
                icon: DesignTokens.Icons.network,
                color: .appConcept,
                unit: L10n.Dashboard.pageListLinks,
                trend: nil,
                layout: .dashboard
            )
        }
    }
    
    private var densityChartSection: some View {
        // 2. 连接密度图表 (语义分块质量)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tightPadding) {
            // 标题 (边框外左上角)
            HStack {
                InsightDashboardSectionTitle(icon: DesignTokens.Icons.network, title: L10n.Dashboard.density, infoAction: { showDensityInfo.toggle() })
                    .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    HapticFeedback.shared.trigger(.selection)
                    router.navigate(to: .graph)
                }) {
                    HStack(spacing: DesignTokens.Spacing.tiny) {
                        Image(systemName: DesignTokens.Icons.circleGrid3x3Fill)
                        Text(L10n.Dashboard.graphShortcut)
                    }
                    .font(.system(size: DesignTokens.Typography.caption2FontSize, weight: .bold))
                    .insightGlassCapsule(color: .appAccent)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, DesignTokens.Spacing.tiny)
            
            if showDensityInfo {
                Text(L10n.Dashboard.densityDesc)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                    .padding(.bottom, DesignTokens.Spacing.tiny)
                    .padding(.leading, DesignTokens.Spacing.tiny)
            }
            
            // 卡片内容 (应用统一容器外框)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.standardPadding) {
                if coordinator.densityData.isEmpty {
                    emptyView
                } else {
                    ConnectionDensityChartView(items: coordinator.densityData)
                        .padding(.bottom, DesignTokens.Spacing.tiny)
                    
                    // 💡 完美的「图例与 X 轴含义说明单行看板」 (Legend & X-Axis Note Panel)
                    // 左右完美对称，信息量饱满且布局轻盈开阔，彻底移除了沉重的胶囊和重复的“纵轴说明”
                    HStack {
                        // 左侧图例（带高亮圆点，富有呼吸感和大厂精致度）
                        HStack(spacing: DesignTokens.Spacing.small) {
                            legendDot(color: Color.appAccent, text: L10n.Dashboard.densityOutbound)
                            legendDot(color: Color.theme.purple, text: L10n.Dashboard.densityInbound)
                        }
                        
                        Spacer()
                        
                        // 右侧双轴物理含义释义 (箭头+含义，通过 | 分隔，完美揭示空间物理轴方向)
                        HStack(spacing: DesignTokens.Spacing.tiny) {
                            axisLegend(icon: DesignTokens.Icons.arrowUp, text: L10n.Dashboard.axisPages)
                            
                            Text("")
                                .font(.system(size: DesignTokens.Typography.caption2FontSize, weight: .bold))
                                .foregroundStyle(.appAccent.opacity(DesignTokens.Opacity.disabled))
                            
                            axisLegend(icon: DesignTokens.Icons.arrowRight, text: L10n.Dashboard.axisRelations)
                        }
                    }
                    .padding(.bottom, DesignTokens.Spacing.tiny)
                }
            }
            .appContainer(padding: true) // 应用统一容器样式
        }
    }
    
    private var dailyInsightsSection: some View {
        // 3. 每日灵感 (AI 合成摘要预览)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tightPadding) {
            HStack {
                Image(systemName: DesignTokens.Icons.sparkles)
                    .font(.caption)
                    .foregroundStyle(.appAccent)
                Text(L10n.Dashboard.dailyInsights)
                    .font(.headline)
                Spacer()
                Button(action: { Task { await coordinator.refreshInsights() } }) {
                    infoButtonIcon(DesignTokens.Icons.refresh)
                }
                .buttonStyle(.plain)
                .disabled(coordinator.isGeneratingInsights)
            }
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                if coordinator.isGeneratingInsights {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(L10n.Dashboard.insightsLoading)
                            .font(.subheadline)
                            .foregroundColor(.appSecondary)
                            .italic()
                        Spacer()
                    }
                    .padding(.vertical, DesignTokens.Spacing.wide)
                } else if let recap = coordinator.dailyRecap {
                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        if store.pages.contains(where: { $0.id == recap.targetPageID }) {
                            router.navigateToPage(id: recap.targetPageID)
                        } else {
                            toastManager.show(type: .info, message: L10n.Dashboard.insightsPageDeleted)
                        }
                    }) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                            Text(recap.targetPageTitle)
                                .font(.system(size: DesignTokens.Typography.subheadlineFontSize, weight: .bold))
                                .foregroundColor(.appAccent)
                            
                            Text(recap.insight)
                                .font(.system(size: DesignTokens.Metrics.dashboardLabelSize))
                                .foregroundColor(.appText)
                                .lineSpacing(DesignTokens.Spacing.tiny)
                                .multilineTextAlignment(.leading)
                            
                            if !recap.suggestedConnection.isEmpty {
                                HStack(alignment: .top, spacing: DesignTokens.Spacing.tiny) {
                                    Image(systemName: DesignTokens.Icons.concept)
                                        .font(.system(size: DesignTokens.Typography.caption2FontSize))
                                        .foregroundColor(.theme.orange)
                                    Text(recap.suggestedConnection)
                                        .font(.system(size: DesignTokens.Typography.captionFontSize, weight: .medium))
                                        .foregroundColor(.appSecondary)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.top, DesignTokens.Spacing.tiny)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("DailyRecapCard")
                } else {
                    Text(L10n.Dashboard.insightsEmpty)
                        .font(.subheadline)
                        .foregroundColor(.appSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(DesignSystem.Layout.cardContentPadding) // 使用标准卡片内边距 (16pt)
            .appMetricCardStyle(color: .appAccent, cornerRadius: DesignTokens.Spacing.standardRadius)
        }
    }
    
    private var hotTopicsSection: some View {
        // 4. 热门领域 (PageType 分布)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tightPadding) {
            InsightDashboardSectionTitle(icon: DesignTokens.Icons.grid, title: L10n.Dashboard.hotTopics)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Grid.standardSpacing) {
                // 遍历用户可见页面类型，屏蔽 raw 选项的统计
                ForEach(PageType.allVisibleCases, id: \.self) { type in
                    let count = store.pages.filter { $0.pageType == type }.count
                    if count > 0 {
                        Button(action: {
                            HapticFeedback.shared.trigger(.selection)
                            router.navigate(to: .pageList(filterType: type))
                        }) {
                            HotTopicMedal(category: type.displayName, count: count, icon: type.icon, color: Color.fromModelColorName(type.colorName))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// 密度图表图例圆点项（圆点 + 文本）
    @ViewBuilder
    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.atomic) {
            Circle()
                .fill(color)
                .frame(width: DesignTokens.IconSize.atomic, height: DesignTokens.IconSize.atomic)
            Text(text)
                .font(.system(size: DesignTokens.Typography.caption2FontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.appSecondary)
        }
    }

    /// 密度图表轴向图例项（箭头图标 + 文本）
    @ViewBuilder
    private func axisLegend(icon: String, text: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.atomic) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.SystemFontSize.micro, weight: .bold))
                .foregroundColor(.appAccent)
            Text(text)
                .font(.system(size: DesignTokens.Typography.caption2FontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.appSecondary)
        }
    }
}

// MARK: - 辅助组件

/// 热门领域勋章 (横向卡片)
struct HotTopicMedal: View {
    let category: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            ZStack {
                Circle()
                    .fill(color.opacity(DesignTokens.Colors.Opacity.glassOpacity))
                    .frame(width: DesignTokens.Metrics.iconBoxSize, height: DesignTokens.Metrics.iconBoxSize)
                Image(systemName: icon)
                    .font(.system(size: DesignTokens.Typography.headlineFontSize))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
                Text(category)
                    .font(.system(size: DesignTokens.Typography.titleFontSize, weight: .bold))
                    .foregroundColor(.appText)
                Text("\(count) " + L10n.Dashboard.pageListPages)
                    .font(.system(size: DesignTokens.Typography.captionFontSize))
                    .foregroundColor(.appSecondary)
            }
            
            Spacer()
        }
        .padding(DesignTokens.Spacing.standardPadding)
        .appMetricCardStyle(color: color, cornerRadius: DesignTokens.Spacing.standardRadius)
    }
}

private var emptyView: some View {
    VStack {
        Image(systemName: DesignTokens.Icons.chartBar)
            .font(.largeTitle)
            .foregroundColor(.appSecondary.opacity(DesignTokens.Opacity.medium))
        Text(L10n.Common.Global.noData)
            .font(.caption)
            .foregroundColor(.appSecondary)
    }
    .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.chartHeight)
}

// MARK: - 信息按钮图标
@ViewBuilder
private func infoButtonIcon(_ systemName: String) -> some View {
    Image(systemName: systemName)
        .font(.caption)
        .foregroundColor(.appSecondary)
}

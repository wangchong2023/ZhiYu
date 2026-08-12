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
import Charts
import Dependencies
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
                Color.theme.black.overlay(themeManager.pageBackground().opacity(DesignSystem.Opacity.disabled))
                MeshGradientView()
                    .blur(radius: 80)
            }
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.huge) {
                    AIProcessingStatusBanner()
                        .padding(.bottom, -DesignSystem.standardPadding)
                        
                    metricSection
                    densityChartSection
                    dailyInsightsSection
                    hotTopicsSection
                }
                .padding()
                .padding(.bottom, DesignSystem.Metrics.chartHeight / 2)
            }
            .scrollIndicators(.hidden)
            
        }
        .appTabToolbar(title: L10n.Common.Sidebar.dashboard, showVaultBadge: false)
        .task(id: store.pages.count) {
            guard !Task.isCancelled else { return }
            await coordinator.refreshAll()
        }
    }
    
    // MARK: - Sub-Sections
    
    private var metricSection: some View {
        // 1. 核心指标概览
        HStack(spacing: DesignSystem.Grid.standardSpacing) {
            MetricBox(
                title: L10n.Dashboard.totalPages, 
                value: "\(store.pages.count)", 
                unit: L10n.Dashboard.pageListPages, 
                icon: DesignSystem.Icons.documentFill, 
                color: .appAccent,
                trend: nil
            )
            MetricBox(
                title: L10n.Dashboard.totalLinks, 
                value: "\(coordinator.totalLinks)", 
                unit: L10n.Dashboard.pageListLinks, 
                icon: DesignSystem.Icons.network, 
                color: .appConcept,
                trend: nil
            )
        }
    }
    
    private var densityChartSection: some View {
        // 2. 连接密度图表 (语义分块质量)
        VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
            // 标题 (边框外左上角)
            HStack(spacing: DesignSystem.tiny) {
                Image(systemName: DesignSystem.Icons.network)
                    .font(.caption)
                    .foregroundStyle(.appAccent)
                Text(L10n.Dashboard.density)
                    .font(.headline)
                Button(action: { showDensityInfo.toggle() }) {
                    Image(systemName: DesignSystem.Icons.info)
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    HapticFeedback.shared.trigger(.selection)
                    router.navigate(to: .graph)
                }) {
                    HStack(spacing: DesignSystem.tiny) {
                        Image(systemName: DesignSystem.Icons.circleGrid3x3Fill)
                        Text(L10n.Dashboard.graphShortcut)
                    }
                    .font(.system(size: DesignSystem.caption2FontSize, weight: .bold))
                    .foregroundStyle(.appAccent)
                    .padding(.horizontal, DesignSystem.Chip.horizontalPadding)
                    .padding(.vertical, DesignSystem.Chip.verticalPadding)
                    .background(Color.appAccent.opacity(DesignSystem.glassOpacity))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, DesignSystem.tiny)
            
            if showDensityInfo {
                Text(L10n.Dashboard.densityDesc)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                    .padding(.bottom, DesignSystem.tiny)
                    .padding(.leading, DesignSystem.tiny)
            }
            
            // 卡片内容 (应用统一容器外框)
            VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
                if coordinator.densityData.isEmpty {
                    emptyView
                } else {
                    // 💡 密度图表重塑：双物理指示直角 Canvas 双箭头坐标轴系统 (去除了所有冗余 layout，彻底对齐 Y 轴与图间距，拉开底轴空气留白)
                    Chart(coordinator.densityData) { item in
                        BarMark(
                            x: .value("Outbound", item.outbound),
                            y: .value("Page", item.name)
                        )
                        .cornerRadius(DesignSystem.Radius.small)
                        .foregroundStyle(LinearGradient(
                            colors: [.appAccent, .appAccent.opacity(DesignSystem.Opacity.dim)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        
                        BarMark(
                            x: .value("Inbound", item.inbound),
                            y: .value("Page", item.name)
                        )
                        .cornerRadius(DesignSystem.Radius.small)
                        .foregroundStyle(LinearGradient(
                            colors: [.purple, .purple.opacity(DesignSystem.Opacity.dim)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                    }
                    .frame(height: DesignSystem.Metrics.chartHeight + DesignSystem.medium)
                    .chartXAxis(.hidden) // 彻底删除冗余“0个关联”等繁杂文案，回归极其大气的物理大厂留白
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let name = value.as(String.self) {
                                    // 正常完整展示具体的页面文案内容（最多支持 12 个汉字，完美适应 iPhone 屏幕宽度，超过时以 "..." 雅致折叠）
                                    Text(name.prefix(12) + (name.count > 12 ? "..." : ""))
                                        .font(.system(size: DesignSystem.captionFontSize, weight: .medium, design: .rounded))
                                        .foregroundStyle(.appSource)
                                }
                            }
                        }
                    }
                    .chartLegend(.hidden)
                    .padding(.bottom, DesignSystem.small) // 额外物理扩展图表底部外边距，形成高级空气流动美感
                    
                    // 💡 完美的「图例与 X 轴含义说明单行看板」 (Legend & X-Axis Note Panel)
                    // 左右完美对称，信息量饱满且布局轻盈开阔，彻底移除了沉重的胶囊和重复的“纵轴说明”
                    HStack {
                        // 左侧图例（带高亮圆点，富有呼吸感和大厂精致度）
                        HStack(spacing: DesignSystem.small) {
                            HStack(spacing: DesignSystem.atomic) {
                                Circle()
                                    .fill(Color.appAccent)
                                    .frame(width: DesignSystem.IconSize.atomic, height: DesignSystem.IconSize.atomic)
                                Text(L10n.Dashboard.densityOutbound)
                                    .font(.system(size: DesignSystem.caption2FontSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(.appSecondary)
                            }
                            
                            HStack(spacing: DesignSystem.atomic) {
                                Circle()
                                    .fill(Color.theme.purple)
                                    .frame(width: DesignSystem.IconSize.atomic, height: DesignSystem.IconSize.atomic)
                                Text(L10n.Dashboard.densityInbound)
                                    .font(.system(size: DesignSystem.caption2FontSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(.appSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        // 右侧双轴物理含义释义 (箭头+含义，通过 | 分隔，完美揭示空间物理轴方向)
                        HStack(spacing: DesignSystem.tiny) {
                            HStack(spacing: DesignSystem.atomic) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: DesignSystem.caption2FontSize - 1, weight: .bold))
                                    .foregroundColor(.appAccent)
                                Text(L10n.Dashboard.axisPages)
                                    .font(.system(size: DesignSystem.caption2FontSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(.appSecondary)
                            }
                            
                            Text("")
                                .font(.system(size: DesignSystem.caption2FontSize, weight: .bold))
                                .foregroundStyle(.appAccent.opacity(DesignSystem.Opacity.disabled))
                            
                            HStack(spacing: DesignSystem.atomic) {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: DesignSystem.caption2FontSize - 1, weight: .bold))
                                    .foregroundColor(.appAccent)
                                Text(L10n.Dashboard.axisRelations)
                                    .font(.system(size: DesignSystem.caption2FontSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(.appSecondary)
                            }
                        }
                    }
                    .padding(.top, -DesignSystem.tiny)
                    .padding(.bottom, DesignSystem.tiny)
                }
            }
            .appContainer(padding: true) // 应用统一容器样式
        }
    }
    
    private var dailyInsightsSection: some View {
        // 3. 每日灵感 (AI 合成摘要预览)
        VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
            HStack {
                Image(systemName: DesignSystem.Icons.sparkles)
                    .font(.caption)
                    .foregroundStyle(.appAccent)
                Text(L10n.Dashboard.dailyInsights)
                    .font(.headline)
                Spacer()
                Button(action: { Task { await coordinator.refreshInsights() } }) {
                    Image(systemName: DesignSystem.Icons.refresh)
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
                .buttonStyle(.plain)
                .disabled(coordinator.isGeneratingInsights)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.medium) {
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
                    .padding(.vertical, DesignSystem.wide)
                } else if let recap = coordinator.dailyRecap {
                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        if store.pages.contains(where: { $0.id == recap.targetPageID }) {
                            router.navigateToPage(id: recap.targetPageID)
                        } else {
                            toastManager.show(type: .info, message: L10n.Dashboard.insightsPageDeleted)
                        }
                    }) {
                        VStack(alignment: .leading, spacing: DesignSystem.small) {
                            Text(recap.targetPageTitle)
                                .font(.system(size: DesignSystem.subheadlineFontSize, weight: .bold))
                                .foregroundColor(.appAccent)
                            
                            Text(recap.insight)
                                .font(.system(size: DesignSystem.Metrics.dashboardLabelSize))
                                .foregroundColor(.appText)
                                .lineSpacing(DesignSystem.tiny)
                                .multilineTextAlignment(.leading)
                            
                            if !recap.suggestedConnection.isEmpty {
                                HStack(alignment: .top, spacing: DesignSystem.tiny) {
                                    Image(systemName: DesignSystem.Icons.concept)
                                        .font(.system(size: DesignSystem.caption2FontSize))
                                        .foregroundColor(.theme.orange)
                                    Text(recap.suggestedConnection)
                                        .font(.system(size: DesignSystem.captionFontSize, weight: .medium))
                                        .foregroundColor(.appSecondary)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.top, DesignSystem.tiny)
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
            .appMetricCardStyle(color: .appAccent, cornerRadius: DesignSystem.standardRadius)
        }
    }
    
    private var hotTopicsSection: some View {
        // 4. 热门领域 (PageType 分布)
        VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
            HStack(spacing: DesignSystem.tiny) {
                Image(systemName: DesignSystem.Icons.grid)
                    .font(.caption)
                    .foregroundStyle(.appAccent)
                Text(L10n.Dashboard.hotTopics)
                    .font(.headline)
            }
            
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
}

// MARK: - 辅助组件

/// 指标卡片
struct MetricBox: View {
    let title: String
    let value: String
    let unit: String?
    let icon: String
    let color: Color
    var trend: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium + DesignSystem.atomic) { // 14pt
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(DesignSystem.glassOpacity))
                        .frame(width: DesignSystem.Timeline.indicatorSize, height: DesignSystem.Timeline.indicatorSize) // 36pt
                    Image(systemName: icon)
                        .font(.system(size: DesignSystem.subheadlineFontSize, weight: .bold))
                        .foregroundColor(color)
                }
                
                Spacer()
                
                if let trend = trend {
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
            
            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(title)
                    .font(.system(size: DesignSystem.captionFontSize, weight: .medium))
                    .foregroundColor(.appSecondary)
                
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.tiny) {
                    Text(value)
                        .font(.system(size: DesignSystem.Metrics.heroValueSize, weight: .bold, design: .rounded))
                        .foregroundColor(.appText)
                    
                    if let unit = unit {
                        Text(unit)
                            .font(.caption2)
                            .foregroundColor(.appSecondary)
                    }
                }
            }
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
}

/// 热门领域勋章 (横向卡片)
struct HotTopicMedal: View {
    let category: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            ZStack {
                Circle()
                    .fill(color.opacity(DesignSystem.glassOpacity))
                    .frame(width: DesignSystem.Metrics.iconBoxSize, height: DesignSystem.Metrics.iconBoxSize)
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.headlineFontSize))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(category)
                    .font(.system(size: DesignSystem.titleFontSize, weight: .bold))
                    .foregroundColor(.appText)
                Text("\(count) " + L10n.Dashboard.pageListPages)
                    .font(.system(size: DesignSystem.captionFontSize))
                    .foregroundColor(.appSecondary)
            }
            
            Spacer()
        }
        .padding(DesignSystem.standardPadding)
        .appMetricCardStyle(color: color, cornerRadius: DesignSystem.standardRadius)
    }
}

private var emptyView: some View {
    VStack {
        Image(systemName: DesignSystem.Icons.chartBar)
            .font(.largeTitle)
            .foregroundColor(.appSecondary.opacity(DesignSystem.Opacity.medium))
        Text(L10n.Common.Global.noData)
            .font(.caption)
            .foregroundColor(.appSecondary)
    }
    .frame(maxWidth: .infinity, minHeight: DesignSystem.Metrics.chartHeight)
}

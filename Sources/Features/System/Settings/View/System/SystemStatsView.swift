//
//  SystemStatsView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 SystemStats 界面的 UI 视图层组件。
//
import SwiftUI
import Charts
import UFPDesignSystem

/// 系统统计视图常量
private enum SystemStatsConstants {
    /// 资产分类网格左缩进 (giant + standardPadding = 40)
    static let assetGridLeadingPadding: CGFloat = 40
}

// MARK: - 资源监控视图
/// [L3] 表现层：资源监控视图 (原资源监控)
/// 提供 AI 资源消耗、存储空间分布及数据溯源的多维度监控。
struct SystemStatsView: View {
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.interfaceIdiom) private var idiom
    
    // 使用协调器管理状态与交互
    @State var coordinator = SystemStatsCoordinator()
    @State private var selectedTab: Tab

    enum Tab: String, CaseIterable {
        case performance
        case storage
        case plugins
        
        var title: String {
            switch self {
            case .performance: return L10n.Dashboard.stats.tabPerf
            case .storage: return L10n.Dashboard.stats.tabStorage
            case .plugins: return L10n.Dashboard.stats.tabPlugins
            }
        }
    }

    init(initialTab: Tab = .performance, coordinator: SystemStatsCoordinator? = nil) {
        _selectedTab = State(initialValue: initialTab)
        if let coordinator = coordinator {
            _coordinator = State(initialValue: coordinator)
        }
    }
    
    var body: some View {
        ZStack {
            themeManager.pageBackground()
                .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    // 分段选择器（与下方卡片保持左对齐与统一边距）
                    HStack {
                        Picker("", selection: $selectedTab) {
                            ForEach(Tab.allCases, id: \.self) { tab in
                                Text(tab.title).tag(tab)
                            }
                        }
                        .labelsHidden()
                        .segmentedPickerStyleIfAvailable()
                        .fixedSize()
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.Spacing.medium)
                    .padding(.top, DesignTokens.Spacing.small)
                    .padding(.bottom, DesignTokens.Spacing.medium)
                    
                    if coordinator.isLoading {
                        VStack {
                            ProgressView()
                                .padding(.vertical, DesignTokens.Spacing.Sidebar.backButtonWidth)
                        }
                    } else {
                        switch selectedTab {
                        case .performance:
                            performanceSection
                        case .storage:
                            storageSection
                        case .plugins:
                            PluginStatsSection()
                                .padding(.horizontal, DesignTokens.Spacing.medium)
                        }
                    }
                }
                .padding(.bottom, DesignTokens.Spacing.huge) // 底部留白
            }
        }
        .appToolbarBackgroundHidden()
        .navigationTitle(L10n.Dashboard.stats.navigationTitleMonitor)
        .toolbar {
            if idiom != .mac {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
        }
        .task {
            await coordinator.loadStats()
        }
    }
    
    // MARK: - 性能与 AI 资源分区
    @ViewBuilder
    private var performanceSection: some View {
        Group {
            // 1. API 请求卡片
            statsChartSection(
                title: L10n.Dashboard.apiRequests + " (\(L10n.Dashboard.stats.rangeThirtyDays))",
                totalValue: coordinator.dailyStats.reduce(0) { $0 + $1.requests },
                valueLabel: L10n.Dashboard.stats.requestsUsage,
                chartType: .requests
            )

            // 2. Token 消耗卡片
            statsChartSection(
                title: L10n.Dashboard.stats.tokensUsage + " (\(L10n.Dashboard.stats.rangeThirtyDays))",
                totalValue: coordinator.dailyStats.reduce(0) { $0 + $1.tokens },
                valueLabel: L10n.Dashboard.tokens,
                chartType: .tokens
            )
            
            // 3. 响应时延卡片
            StandardSection(title: L10n.Dashboard.stats.latencyTitle + " (\(L10n.Dashboard.stats.rangeThirtyDays))") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.standardPadding) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                            Text(L10n.Dashboard.stats.avgLatencyShort)
                                .font(.caption)
                                .foregroundStyle(.appSecondary)
                            
                            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.tiny) {
                                Text("\(coordinator.avgLatency)")
                                    .font(.system(size: DesignTokens.Typography.displayFontSize, weight: .bold, design: .rounded))
                                    .foregroundColor(.appText)
                                Text(L10n.Dashboard.unitMs)
                                    .font(.system(size: DesignTokens.Typography.subheadlineFontSize, weight: .semibold))
                                    .foregroundColor(.appSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill((coordinator.avgLatency > AppConstants.Performance.latencyWarningThreshold ? Color.theme.orange : Color.appAccent).opacity(DesignTokens.Opacity.subtle))
                                .frame(width: DesignTokens.IconSize.xlarge, height: DesignTokens.IconSize.xlarge)
                            Image(systemName: DesignTokens.Icons.timer)
                                .font(.title3.bold())
                                .foregroundColor(coordinator.avgLatency > AppConstants.Performance.latencyWarningThreshold ? Color.theme.orange : .appAccent)
                        }
                    }
                    
                    Divider()
                        .opacity(DesignTokens.Colors.Opacity.softOpacity)
                    
                    HStack(spacing: 0) {
                        latencySubValue(label: L10n.Dashboard.stats.maxLatency, value: "\(coordinator.maxLatency)")
                        divider
                        latencySubValue(label: L10n.Dashboard.stats.minLatency, value: "\(coordinator.minLatency)")
                        divider
                        latencySubValue(label: L10n.Dashboard.stats.measureCount, value: "\(coordinator.latencyCount)")
                    }
                }
                .padding(DesignTokens.Spacing.medium)
            }
        }
    }
    
    // MARK: - 存储与治理分区
    @ViewBuilder
    private var storageSection: some View {
        Group {
            // 1. 知识库资产分布 (饼图 + 详细图例)
            StandardSection(title: L10n.Dashboard.stats.storageDistribution) {
                VStack(spacing: DesignTokens.Spacing.medium) {
                    if coordinator.storageCategories.isEmpty {
                        ProgressView()
                            .frame(height: DesignTokens.ComponentSpacing.chartHeight)
                    } else if coordinator.storageCategories.allSatisfy({ $0.value == 0 }) {
                        VStack(spacing: DesignTokens.Spacing.medium) {
                            Image(systemName: DesignTokens.Icons.chartPie)
                                .font(.system(size: DesignSystem.Gallery.iconSize))
                                .foregroundStyle(.appSecondary.opacity(DesignTokens.Colors.Opacity.softOpacity))
                            Text(L10n.Common.Global.noData)
                                .font(.caption)
                                .foregroundStyle(.appSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: DesignTokens.ComponentSpacing.chartHeight)
                    } else {
                        HStack(spacing: DesignTokens.Spacing.medium) {
                            chartContainer
                                .skipOnWatch { $0.frame(maxWidth: .infinity, alignment: .center) }
                            
                            legendContainer
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, DesignTokens.Spacing.small)
                    }
                }
                .padding(DesignTokens.Spacing.medium)
            }
            
            // 2. 存储空间分布列表
            StandardSection(title: L10n.Dashboard.stats.storageDetails) {
                ForEach(coordinator.storageCategories) { category in
                    let isLast = category.id == coordinator.storageCategories.last?.id
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: DesignTokens.Spacing.standardPadding) {
                            Image(systemName: coordinator.iconForCategory(category.label))
                                .foregroundStyle(category.color)
                                .frame(width: DesignTokens.Spacing.giant)
                            
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
                                Text(category.label)
                                    .foregroundStyle(.appText)
                                
                                if category.label == L10n.Dashboard.System.database {
                                    Text(L10n.Dashboard.stats.multiVaultDesc(category.count))
                                        .font(.system(size: DesignTokens.Typography.microFontSize))
                                        .foregroundStyle(.appSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.atomic) {
                                HStack(spacing: DesignTokens.Spacing.tiny) {
                                    Text(coordinator.formatBytes(category.value))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.appText)
                                }
                                
                                if coordinator.totalStorage > 0 {
                                    let percent = Int(Double(category.value) / Double(coordinator.totalStorage) * Double(FeatureConstants.PercentageBase.fullInt))
                                    percentText(percent)
                                }
                            }
                        }
                        
                        if category.label == L10n.Dashboard.stats.storageImport {
                            let voice = coordinator.assetCategoryStats["voice"] ?? SystemStatsCoordinator.AssetStats(count: 0, size: 0)
                            let ocr = coordinator.assetCategoryStats["ocr"] ?? SystemStatsCoordinator.AssetStats(count: 0, size: 0)
                            let file = coordinator.assetCategoryStats["file"] ?? SystemStatsCoordinator.AssetStats(count: 0, size: 0)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.Spacing.small) {
                                assetCategoryGridItem(title: L10n.Dashboard.stats.audioFormat, count: voice.count, size: voice.size, color: Color.theme.indigo)
                                assetCategoryGridItem(title: L10n.Dashboard.stats.imageFormat, count: ocr.count, size: ocr.size, color: Color.theme.orange)
                                assetCategoryGridItem(title: L10n.Dashboard.stats.documentFormat, count: file.count, size: file.size, color: Color.theme.teal)
                            }
                            .padding(.top, DesignTokens.Spacing.small)
                            .padding(.leading, SystemStatsConstants.assetGridLeadingPadding)
                        }
                    }
                    .appListRowStyle(showDivider: !isLast)
                }
            }
            
            // 2.5 各笔记本存储占用 (仅在存在多笔记本时渲染)
            if !coordinator.vaultStorageItems.isEmpty {
                StandardSection(title: L10n.Dashboard.stats.vaultStorageTitle) {
                    ForEach(coordinator.vaultStorageItems) { item in
                        let isLast = item.id == coordinator.vaultStorageItems.last?.id
                        HStack(spacing: DesignTokens.Spacing.standardPadding) {
                            // 笔记本专属图标
                            ZStack {
                                Circle()
                                    .fill(Color.appAccent.opacity(DesignTokens.Opacity.subtle))
                                    .frame(width: DesignTokens.IconSize.large, height: DesignTokens.IconSize.large)
                                Image(systemName: item.icon.isEmpty ? "books.vertical.fill" : item.icon)
                                    .font(.system(size: DesignTokens.Typography.captionFontSize))
                                    .foregroundStyle(.appAccent)
                            }
                            
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
                                Text(item.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.appText)
                                
                                // 当前是否处于激活/选中使用中
                                if item.id == VaultService.shared.selectedVaultID {
                                    Text(L10n.Dashboard.stats.activeVaultStatus)
                                        .font(.caption2)
                                        .foregroundStyle(Color.theme.green)
                                } else {
                                    Text(L10n.Dashboard.stats.inactiveVaultStatus)
                                        .font(.caption2)
                                        .foregroundStyle(.appSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.atomic) {
                                Text(coordinator.formatBytes(item.size))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.appText)
                                
                                // 计算所占总数据库大小的百分比
                                let dbTotal = coordinator.storageCategories.first { $0.label == L10n.Dashboard.System.database }?.value ?? 1
                                let percent = Int(Double(item.size) / Double(max(1, dbTotal)) * Double(FeatureConstants.PercentageBase.fullInt))
                                percentText(percent)
                            }
                        }
                        .appListRowStyle(showDivider: !isLast)
                    }
                }
            }
            
            // 2.6 原始文件列表查看入口
            StandardSection(title: L10n.Dashboard.stats.rawStorageTitle) {
                NavigationLink {
                    RawStorageListView()
                } label: {
                    HStack {
                        Label(L10n.Dashboard.stats.viewRawPages, systemImage: DesignTokens.Icons.docPlaintext)
                        Spacer()
                        Image(systemName: DesignTokens.Icons.forward)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                    }
                    .padding(DesignTokens.Spacing.medium)
                }
                .buttonStyle(.plain)
            }

            // 3. 治理与维护
            StandardSection(title: L10n.Dashboard.maintenance) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    Button(action: { Task { await coordinator.cleanupData() } }) {
                        HStack {
                            Label(L10n.Dashboard.cleanupAction, systemImage: DesignTokens.Icons.sparkles)
                            Spacer()
                            if coordinator.isCleaning {
                                ProgressView()
                            } else {
                                Image(systemName: DesignTokens.Icons.forward)
                                    .font(.caption)
                                    .foregroundStyle(.appSecondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.appAccent)
                    
                    if let count = coordinator.cleanedCount {
                        Text("\(L10n.Dashboard.cleanedPrefix) \(count) \(L10n.Dashboard.cleanedSuffix)")
                            .font(.caption)
                            .foregroundColor(Color.theme.green)
                    }
                }
                .padding(DesignTokens.Spacing.medium)
            }
        }
    }
}

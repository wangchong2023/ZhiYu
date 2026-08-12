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

// MARK: - 资源监控视图
/// [L3] 表现层：资源监控视图 (原资源监控)
/// 提供 AI 资源消耗、存储空间分布及数据溯源的多维度监控。
struct SystemStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) var store
    @Environment(ThemeManager.self) var themeManager
    
    // 使用协调器管理状态与交互
    @State private var coordinator = SystemStatsCoordinator()
    @State private var selectedTab: Tab = .performance
    
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
    
    var body: some View {
        ZStack {
            themeManager.pageBackground()
                .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    // 分段选择器
                    Picker("", selection: $selectedTab) {
                        ForEach(Tab.allCases, id: \.self) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .segmentedPickerStyleIfAvailable()
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.medium)
                    
                    if coordinator.isLoading {
                        VStack {
                            ProgressView()
                                .padding(.vertical, Spacing.Sidebar.backButtonWidth)
                        }
                    } else {
                        switch selectedTab {
                        case .performance:
                            performanceSection
                        case .storage:
                            storageSection
                        case .plugins:
                            PluginStatsSection()
                                .padding(.horizontal, Spacing.medium)
                        }
                    }
                }
                .padding(.bottom, DesignSystem.huge) // 底部留白
            }
            .background(PageBackgroundView(accentColor: .appAccent))
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle(L10n.Dashboard.stats.navigationTitleMonitor)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.Common.done) {
                    dismiss()
                }
                .bold()
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
            StandardSection(title: L10n.Dashboard.apiRequests + " (\(L10n.Dashboard.stats.rangeThirtyDays))") {
                VStack(alignment: .leading, spacing: Spacing.tiny) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignSystem.small) {
                        Text("\(coordinator.dailyStats.reduce(0) { $0 + $1.requests })")
                            .font(.system(size: DesignSystem.titleFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.appText)
                        Text(L10n.Dashboard.stats.requestsUsage)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                    }
                    
                    ChartView(stats: coordinator.dailyStats, type: .requests)
                        .frame(height: DesignSystem.Metrics.chartHeight - 40)
                }
                .padding(Spacing.medium)
            }
            
            // 2. Token 消耗卡片
            StandardSection(title: L10n.Dashboard.stats.tokensUsage + " (\(L10n.Dashboard.stats.rangeThirtyDays))") {
                VStack(alignment: .leading, spacing: Spacing.tiny) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignSystem.small) {
                        Text("\(coordinator.dailyStats.reduce(0) { $0 + $1.tokens })")
                            .font(.system(size: DesignSystem.titleFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.appText)
                        Text(L10n.Dashboard.tokens)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                    }
                    
                    ChartView(stats: coordinator.dailyStats, type: .tokens)
                        .frame(height: DesignSystem.Metrics.chartHeight - 40)
                }
                .padding(Spacing.medium)
            }
            
            // 3. 响应时延卡片
            StandardSection(title: L10n.Dashboard.stats.latencyTitle + " (\(L10n.Dashboard.stats.rangeThirtyDays))") {
                VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                            Text(L10n.Dashboard.stats.avgLatencyShort)
                                .font(.caption)
                                .foregroundStyle(.appSecondary)
                            
                            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.tiny) {
                                Text("\(coordinator.avgLatency)")
                                    .font(.system(size: DesignSystem.displayFontSize, weight: .bold, design: .rounded))
                                    .foregroundColor(.appText)
                                Text(L10n.Dashboard.unitMs)
                                    .font(.system(size: DesignSystem.subheadlineFontSize, weight: .semibold))
                                    .foregroundColor(.appSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill((coordinator.avgLatency > AppConstants.Performance.latencyWarningThreshold ? Color.theme.orange : Color.appAccent).opacity(DesignSystem.Opacity.subtle))
                                .frame(width: DesignSystem.IconSize.xlarge, height: DesignSystem.IconSize.xlarge)
                            Image(systemName: DesignSystem.Icons.timer)
                                .font(.title3.bold())
                                .foregroundColor(coordinator.avgLatency > AppConstants.Performance.latencyWarningThreshold ? Color.theme.orange : .appAccent)
                        }
                    }
                    
                    Divider()
                        .opacity(DesignSystem.softOpacity)
                    
                    HStack(spacing: 0) {
                        latencySubValue(label: L10n.Dashboard.stats.maxLatency, value: "\(coordinator.maxLatency)")
                        divider
                        latencySubValue(label: L10n.Dashboard.stats.minLatency, value: "\(coordinator.minLatency)")
                        divider
                        latencySubValue(label: L10n.Dashboard.stats.measureCount, value: "\(coordinator.latencyCount)")
                    }
                }
                .padding(Spacing.medium)
            }
        }
    }
    
    // MARK: - 存储与治理分区
    @ViewBuilder
    private var storageSection: some View {
        Group {
            // 1. 知识库资产分布 (饼图 + 详细图例)
            StandardSection(title: L10n.Dashboard.stats.storageDistribution) {
                VStack(spacing: Spacing.medium) {
                    if coordinator.storageCategories.isEmpty {
                        ProgressView()
                            .frame(height: DesignSystem.Metrics.chartHeight - 20)
                    } else if coordinator.storageCategories.allSatisfy({ $0.value == 0 }) {
                        VStack(spacing: Spacing.medium) {
                            Image(systemName: DesignSystem.Icons.chartPie)
                                .font(.system(size: DesignSystem.Gallery.iconSize))
                                .foregroundStyle(.appSecondary.opacity(DesignSystem.softOpacity))
                            Text(L10n.Common.Global.noData)
                                .font(.caption)
                                .foregroundStyle(.appSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: DesignSystem.Metrics.chartHeight - 20)
                    } else {
                        HStack(spacing: Spacing.medium) {
                            chartContainer
                                .skipOnWatch { $0.frame(maxWidth: .infinity, alignment: .center) }
                            
                            legendContainer
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, Spacing.small)
                    }
                }
                .padding(Spacing.medium)
            }
            
            // 2. 存储空间分布列表
            StandardSection(title: L10n.Dashboard.stats.storageDetails) {
                ForEach(coordinator.storageCategories.indices, id: \.self) { index in
                    let category = coordinator.storageCategories[index]
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: Spacing.standardPadding) {
                            Image(systemName: coordinator.iconForCategory(category.label))
                                .foregroundStyle(category.color)
                                .frame(width: DesignSystem.giant)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                                Text(category.label)
                                    .foregroundStyle(.appText)
                                
                                if category.label == L10n.Dashboard.System.database {
                                    Text(L10n.Dashboard.stats.multiVaultDesc(category.count))
                                        .font(.system(size: DesignSystem.microFontSize))
                                        .foregroundStyle(.appSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: DesignSystem.atomic) {
                                HStack(spacing: DesignSystem.tiny) {
                                    Text(coordinator.formatBytes(category.value))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.appText)
                                }
                                
                                if coordinator.totalStorage > 0 {
                                    let percent = Int(Double(category.value) / Double(coordinator.totalStorage) * 100)
                                    Text("\(percent)%")
                                        .font(.system(size: DesignSystem.microFontSize, design: .rounded))
                                        .foregroundStyle(.appSecondary)
                                }
                            }
                        }
                        
                        if category.label == L10n.Dashboard.stats.storageImport {
                            let voice = coordinator.assetCategoryStats["voice"] ?? SystemStatsCoordinator.AssetStats(count: 0, size: 0)
                            let ocr = coordinator.assetCategoryStats["ocr"] ?? SystemStatsCoordinator.AssetStats(count: 0, size: 0)
                            let file = coordinator.assetCategoryStats["file"] ?? SystemStatsCoordinator.AssetStats(count: 0, size: 0)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.small) {
                                assetCategoryGridItem(title: L10n.Dashboard.stats.audioFormat, count: voice.count, size: voice.size, color: .indigo)
                                assetCategoryGridItem(title: L10n.Dashboard.stats.imageFormat, count: ocr.count, size: ocr.size, color: .orange)
                                assetCategoryGridItem(title: L10n.Dashboard.stats.documentFormat, count: file.count, size: file.size, color: .teal)
                            }
                            .padding(.top, DesignSystem.small)
                            .padding(.leading, DesignSystem.giant + Spacing.standardPadding)
                        }
                    }
                    .appListRowStyle(showDivider: index < coordinator.storageCategories.count - 1)
                }
            }
            
            // 2.5 各笔记本存储占用 (仅在存在多笔记本时渲染)
            if !coordinator.vaultStorageItems.isEmpty {
                StandardSection(title: L10n.Dashboard.stats.vaultStorageTitle) {
                    ForEach(coordinator.vaultStorageItems.indices, id: \.self) { index in
                        let item = coordinator.vaultStorageItems[index]
                        HStack(spacing: Spacing.standardPadding) {
                            // 笔记本专属图标
                            ZStack {
                                Circle()
                                    .fill(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                                    .frame(width: DesignSystem.IconSize.large, height: DesignSystem.IconSize.large)
                                Image(systemName: item.icon.isEmpty ? "books.vertical.fill" : item.icon)
                                    .font(.system(size: DesignSystem.captionFontSize))
                                    .foregroundStyle(.appAccent)
                            }
                            
                            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
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
                            
                            VStack(alignment: .trailing, spacing: DesignSystem.atomic) {
                                Text(coordinator.formatBytes(item.size))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.appText)
                                
                                // 计算所占总数据库大小的百分比
                                let dbTotal = coordinator.storageCategories.first { $0.label == L10n.Dashboard.System.database }?.value ?? 1
                                let percent = Int(Double(item.size) / Double(max(1, dbTotal)) * 100)
                                Text("\(percent)%")
                                    .font(.system(size: DesignSystem.microFontSize, design: .rounded))
                                    .foregroundStyle(.appSecondary)
                            }
                        }
                    .appListRowStyle(showDivider: index < coordinator.vaultStorageItems.count - 1)
                    }
                }
            }
            
            // 2.6 原始文件列表查看入口
            StandardSection(title: L10n.Dashboard.stats.rawStorageTitle) {
                NavigationLink {
                    RawStorageListView()
                } label: {
                    HStack {
                        Label(L10n.Dashboard.stats.viewRawPages, systemImage: "doc.plaintext")
                        Spacer()
                        Image(systemName: DesignSystem.Icons.forward)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                    }
                    .padding(Spacing.medium)
                }
                .buttonStyle(.plain)
            }

            // 3. 治理与维护
            StandardSection(title: L10n.Dashboard.maintenance) {
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    Button(action: { Task { await coordinator.cleanupData() } }) {
                        HStack {
                            Label(L10n.Dashboard.cleanupAction, systemImage: "sparkles")
                            Spacer()
                            if coordinator.isCleaning {
                                ProgressView()
                            } else {
                                Image(systemName: DesignSystem.Icons.forward)
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
                .padding(Spacing.medium)
            }
        }
    }
    
    // MARK: - 辅助组件
    
    private var chartContainer: some View {
        ZStack {
            Chart(coordinator.storageCategories) { category in
                SectorMark(
                    angle: .value("Size", Double(category.value)),
                    innerRadius: .ratio(0.65),
                    angularInset: 3
                )
                .cornerRadius(6)
                .foregroundStyle(category.color)
            }
            .chartLegend(.hidden)
            .frame(height: DesignSystem.Metrics.chartHeight - 40)
            
            VStack(spacing: DesignSystem.tiny) {
                Text(coordinator.formatBytes(coordinator.totalStorage))
                    .font(.system(size: DesignSystem.titleFontSize + 2, weight: .bold, design: .rounded))
                    .foregroundStyle(.appAccent)
                Text(L10n.Dashboard.totalStorage)
                    .font(.system(size: DesignSystem.microFontSize, weight: .black))
                    .foregroundStyle(.appSecondary)
                    .kerning(1)
                    .textCase(.uppercase)
            }
        }
    }
    
    private var legendContainer: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            ForEach(coordinator.storageCategories) { category in
                HStack(spacing: DesignSystem.tiny) {
                    Circle()
                        .fill(category.color)
                        .frame(width: DesignSystem.tiny + 2, height: DesignSystem.tiny + 2)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(category.label)
                            .font(DesignSystem.caption2Font)
                            .foregroundStyle(.appText)
                            .lineLimit(1)
                        HStack(spacing: DesignSystem.tiny) {
                            Text(coordinator.formatBytes(category.value))
                            let percent = coordinator.totalStorage > 0 ? Int(Double(category.value) / Double(coordinator.totalStorage) * 100) : 0
                            Text("(\(percent)%)")
                        }
                        .font(.system(size: DesignSystem.microFontSize))
                        .foregroundStyle(.appSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 时延卡片辅助
    
    private func latencySubValue(label: String, value: String) -> some View {
        VStack(alignment: .center, spacing: DesignSystem.tiny) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.appSecondary)
            
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.appText)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var divider: some View {
        Divider()
            .frame(height: DesignSystem.IconSize.micro)
            .padding(.horizontal, DesignSystem.tiny)
    }
    
    private func assetCategoryGridItem(title: String, count: Int, size: Int64, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.atomic) {
            Text(title)
                .font(.system(size: 10, weight: .bold)) // Dynamic Type
                .foregroundStyle(.secondary)
            
            Text(L10n.Dashboard.stats.itemsCount(count))
                .font(.subheadline.bold())
                .foregroundStyle(.appText)
            
            Text(coordinator.formatBytes(size))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(DesignSystem.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard.opacity(DesignSystem.Opacity.subtle))
        .cornerRadius(DesignSystem.smallRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                .stroke(color.opacity(DesignSystem.Opacity.shadow), lineWidth: 1)
        )
    }
}

//
//  WeeklyInsightCard.swift
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

// 周报卡片组件特定常量
private enum WeeklyCardConstants {
    /// 核心指标分隔线高度
    static let dividerHeight: CGFloat = 36
}

/// 知识周报卡片 (PM 视角：价值闭环)
/// 知识周报卡片容器
/// 集成 AI 摘要与核心增长指标的可视化面板
struct WeeklyInsightCard: View {
    @Environment(AppStore.self) var store
    @Environment(AIInsightStore.self) var aiStore
    @Environment(Router.self) var router
    @State private var isGenerating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.loosePadding) {
            HStack {
                AppGlow(icon: DesignTokens.Icons.sparkles, color: .purple, size: DesignTokens.SystemFontSize.title) // 24
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
                    Text(L10n.Dashboard.insight.weeklyTitle)
                        .font(.title3.bold())
                        .foregroundStyle(.appText)
                    if let insight = aiStore.weeklyInsight {
                        Text(insight.dateRange)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                    }
                }
                Spacer()
                
                if isGenerating {
                    ProgressView().scaleEffect(DesignTokens.Animation.pressScale) // 0.8
                } else {
                    Button(action: { generateInsight(forceRefresh: true) }) {
                        Image(systemName: DesignTokens.Icons.refresh)
                            .font(.caption.bold())
                            .foregroundStyle(.appSecondary)
                            .padding(DesignTokens.Spacing.small)
                            .background(Circle().fill(Color.appBorder.opacity(DesignTokens.Colors.Opacity.dimmedOpacity))) // 0.2
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if isGenerating {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    AppSkeleton(width: 200, height: 20)
                    AppSkeleton(width: 300, height: 16)
                    AppSkeleton(width: 260, height: 16)
                    AppSkeleton(width: 280, height: 16)
                }
                .transition(.opacity)
            } else if let insight = aiStore.weeklyInsight {
                VStack(alignment: .leading, spacing: DesignTokens.Metrics.sectionSpacing) { // 24
                    // 核心指标 (奖牌化设计)
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.standardPadding) {
                        HStack(spacing: DesignTokens.Metrics.sectionSpacing) { // 24
                            InsightMetricCard(title: L10n.Common.Stats.newPages, value: "\(insight.totalNewPages)", icon: DesignTokens.Icons.docBadgePlus, color: .blue, layout: .weekly)
                            Divider().frame(height: WeeklyCardConstants.dividerHeight) // 36
                            InsightMetricCard(title: L10n.Common.Stats.growth, value: insight.growthTraction, icon: DesignTokens.Icons.chartLine, color: .green, layout: .weekly)
                        }
                        
                        if !insight.topKeywords.isEmpty {
                            FlowLayout(spacing: DesignTokens.Spacing.small) {
                                ForEach(Array(Set(insight.topKeywords)).sorted(), id: \.self) { tag in
                                    InsightTagChip(
                                        text: tag,
                                        hashPrefix: true,
                                        foregroundColor: .appAccent,
                                        font: DesignTokens.Typography.caption2Font,
                                        style: InsightTagChipStyle(
                                            backgroundColor: .appAccent,
                                            backgroundOpacity: DesignTokens.Colors.Opacity.glassOpacity,
                                            borderColor: .clear,
                                            borderOpacity: 0
                                        )
                                    )
                                }
                            }
                        }
                    }
                    .weeklyInsightContainerStyle()

                    // 摘要正文
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.standardPadding) { // 12
                        HStack {
                            Image(systemName: DesignTokens.Icons.quoteOpening)
                                .font(.title2)
                                .foregroundStyle(.appAccent.opacity(DesignTokens.SystemOpacity.glassStrong)) // 0.3
                            Spacer()
                        }
                        
                        MarkdownRendererView(content: insight.aiSummary, isPrivate: false, onLinkTap: { title in
                            if let page = store.pages.first(where: { $0.title == title }) {
                                router.navigateToPage(id: page.id)
                            }
                        })
                        .padding(.horizontal, DesignTokens.Spacing.small) // 4
                        
                        HStack {
                            Spacer()
                            Image(systemName: DesignTokens.Icons.quoteClosing)
                                .font(.title2)
                                .foregroundStyle(.appAccent.opacity(DesignTokens.Colors.Opacity.disabledOpacity))
                        }
                    }
                    .padding(DesignTokens.Spacing.loosePadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius) // 16
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius)
                                    .stroke(LinearGradient(colors: [DesignSystem.containerBorder, .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: DesignTokens.Spacing.borderWidth)
                            )
                    }
                    .shadow(color: .primary.opacity(DesignTokens.Reference.Opacity.ten), radius: DesignTokens.Spacing.shadowRadius, y: DesignTokens.Spacing.shadowY) // 0.1, 10, 4
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            } else {
                Button(action: { generateInsight(forceRefresh: true) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                            Text(L10n.Dashboard.insight.generateReport)
                                .font(.headline)
                            Text(L10n.Insight.Weekly.aiAnalysis)
                                .font(.caption)
                        }
                        Spacer()
                        Image(systemName: DesignTokens.Icons.sparkles)
                            .font(.title2)
                    }
                    .padding(DesignTokens.Metrics.sectionSpacing) // 24
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius) // 16
                            .fill(LinearGradient(colors: [.appAccent.opacity(DesignTokens.SystemOpacity.glass), .appAccent.opacity(DesignTokens.SystemOpacity.ghost)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius).stroke(DesignSystem.containerBorder, lineWidth: DesignTokens.Spacing.borderWidth))
                    )
                    .foregroundStyle(.appAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Metrics.sectionSpacing) // 24
        .background(
            ZStack {
                DesignSystem.containerBackground
                LinearGradient(colors: [Color.theme.purple.opacity(DesignTokens.SystemOpacity.ghost), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.loosePadding)) // 20
        .shadow(color: .primary.opacity(DesignTokens.Reference.Opacity.ten), radius: DesignTokens.SystemSpacing.content, x: 0, y: DesignTokens.SystemSpacing.element) // 0.1, 16, 8
        .onAppear {
            if aiStore.weeklyInsight == nil && !store.pages.isEmpty {
                generateInsight()
            }
        }
    }
    
    /**
     * @description: 触发周报生成任务，通过 AIWorkflowStore 调度分析逻辑
     * @param {Bool} forceRefresh 是否强制重新生成，忽略缓存
     * @return {*}
     */
    private func generateInsight(forceRefresh: Bool = false) {
        withAnimation { isGenerating = true }
        Task {
            await aiStore.generateWeeklyInsight(forceRefresh: forceRefresh)
            await MainActor.run {
                withAnimation { isGenerating = false }
            }
        }
    }
}

/// 周报指标项小组件
/// 知识周报详情全屏视图
struct WeeklyReportView: View {
    @Environment(AppStore.self) var store
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Metrics.sectionSpacing) { // 24
                WeeklyInsightCard()
                
                // 深度建议
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.standardPadding) {
                    HStack {
                        Image(systemName: DesignTokens.Icons.concept)
                            .foregroundStyle(Color.theme.orange)
                        Text(L10n.Dashboard.insight.tips.title)
                            .font(.headline)
                    }
                    
                    Text(L10n.Dashboard.insight.tips.content)
                        .font(.subheadline)
                        .lineSpacing(DesignTokens.SystemSpacing.small) // 6
                        .foregroundStyle(.appSecondary)
                        .weeklyInsightContainerStyle()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, DesignTokens.SystemSpacing.elementLarge) // 10
                
                // 底部占位，增加留白感
                Spacer(minLength: DesignTokens.Metrics.iconBoxSize) // 40
            }
            .padding(DesignTokens.Spacing.loosePadding)
        }
        .background(PageBackgroundView(accentColor: Color.theme.purple))
        .appSubPageToolbar(title: L10n.Common.Sidebar.weeklyInsight)
    }
}

// MARK: - 周报洞察容器样式
private extension View {
    /// 周报洞察容器：padding + containerCardStyle
    func weeklyInsightContainerStyle() -> some View {
        self
            .padding(DesignTokens.Spacing.loosePadding)
            .containerCardStyle()
    }
}

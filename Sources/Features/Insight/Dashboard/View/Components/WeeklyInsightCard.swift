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
        VStack(alignment: .leading, spacing: DesignSystem.loosePadding) {
            HStack {
                AppGlow(icon: DesignSystem.Icons.sparkles, color: .purple, size: SystemFontSize.title) // 24
                VStack(alignment: .leading, spacing: DesignSystem.atomic) {
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
                    ProgressView().scaleEffect(DesignSystem.Animation.pressScale) // 0.8
                } else {
                    Button(action: { generateInsight(forceRefresh: true) }) {
                        Image(systemName: DesignSystem.Icons.refresh)
                            .font(.caption.bold())
                            .foregroundStyle(.appSecondary)
                            .padding(DesignSystem.small)
                            .background(Circle().fill(Color.appBorder.opacity(DesignSystem.dimmedOpacity))) // 0.2
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if isGenerating {
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    AppSkeleton(width: 200, height: 20)
                    AppSkeleton(width: 300, height: 16)
                    AppSkeleton(width: 260, height: 16)
                    AppSkeleton(width: 280, height: 16)
                }
                .transition(.opacity)
            } else if let insight = aiStore.weeklyInsight {
                VStack(alignment: .leading, spacing: DesignSystem.Metrics.sectionSpacing) { // 24
                    // 核心指标 (奖牌化设计)
                    VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
                        HStack(spacing: DesignSystem.Metrics.sectionSpacing) { // 24
                            InsightStat(label: L10n.Common.Stats.newPages, value: "\(insight.totalNewPages)", icon: DesignSystem.Icons.docBadgePlus, color: .blue)
                            Divider().frame(height: WeeklyCardConstants.dividerHeight) // 36
                            InsightStat(label: L10n.Common.Stats.growth, value: insight.growthTraction, icon: DesignSystem.Icons.chartLine, color: .green)
                        }
                        
                        if !insight.topKeywords.isEmpty {
                            FlowLayout(spacing: DesignSystem.small) {
                                ForEach(Array(Set(insight.topKeywords)).sorted(), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(DesignSystem.caption2Font) // 11
                                        .padding(.horizontal, SystemSpacing.elementLarge) // 10
                                        .padding(.vertical, SystemSpacing.small) // 6
                                        .background(Color.appAccent.opacity(DesignSystem.glassOpacity))
                                        .foregroundStyle(.appAccent)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(DesignSystem.loosePadding) // 添加内边距，解决内容过于拥挤的问题
                    .background(DesignSystem.containerBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius)) // 16
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                            .stroke(DesignSystem.containerBorder, lineWidth: DesignSystem.borderWidth)
                    )

                    // 摘要正文
                    VStack(alignment: .leading, spacing: DesignSystem.standardPadding) { // 12
                        HStack {
                            Image(systemName: DesignSystem.Icons.quoteOpening)
                                .font(.title2)
                                .foregroundStyle(.appAccent.opacity(SystemOpacity.glassStrong)) // 0.3
                            Spacer()
                        }
                        
                        MarkdownRendererView(content: insight.aiSummary, isPrivate: false, onLinkTap: { title in
                            if let page = store.pages.first(where: { $0.title == title }) {
                                router.navigateToPage(id: page.id)
                            }
                        })
                        .padding(.horizontal, DesignSystem.small) // 4
                        
                        HStack {
                            Spacer()
                            Image(systemName: DesignSystem.Icons.quoteClosing)
                                .font(.title2)
                                .foregroundStyle(.appAccent.opacity(DesignSystem.disabledOpacity))
                        }
                    }
                    .padding(DesignSystem.loosePadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: DesignSystem.cardRadius) // 16
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                                    .stroke(LinearGradient(colors: [DesignSystem.containerBorder, .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: DesignSystem.borderWidth)
                            )
                    }
                    .shadow(color: .primary.opacity(Reference.Opacity.ten), radius: DesignSystem.shadowRadius, y: DesignSystem.shadowY) // 0.1, 10, 4
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            } else {
                Button(action: { generateInsight(forceRefresh: true) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                            Text(L10n.Dashboard.insight.generateReport)
                                .font(.headline)
                            Text(L10n.Insight.Weekly.aiAnalysis)
                                .font(.caption)
                        }
                        Spacer()
                        Image(systemName: DesignSystem.Icons.sparkles)
                            .font(.title2)
                    }
                    .padding(DesignSystem.Metrics.sectionSpacing) // 24
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.cardRadius) // 16
                            .fill(LinearGradient(colors: [.appAccent.opacity(SystemOpacity.glass), .appAccent.opacity(SystemOpacity.ghost)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: DesignSystem.cardRadius).stroke(DesignSystem.containerBorder, lineWidth: DesignSystem.borderWidth))
                    )
                    .foregroundStyle(.appAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSystem.Metrics.sectionSpacing) // 24
        .background(
            ZStack {
                DesignSystem.containerBackground
                LinearGradient(colors: [.purple.opacity(SystemOpacity.ghost), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.loosePadding)) // 20
        .shadow(color: .primary.opacity(Reference.Opacity.ten), radius: SystemSpacing.content, x: 0, y: SystemSpacing.element) // 0.1, 16, 8
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
struct InsightStat: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Metrics.iconBoxSize / 2, weight: .semibold)) // 20
                .foregroundStyle(color)
                .frame(width: ComponentSpacing.buttonHeight, height: ComponentSpacing.buttonHeight) // 44
                .background(
                    Circle()
                        .fill(color.opacity(SystemOpacity.glass))
                        .overlay(Circle().stroke(color.opacity(DesignSystem.disabledOpacity), lineWidth: DesignSystem.borderWidth))
                )
            
            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.appText)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
            }
        }
    }
}

/// 知识周报详情全屏视图
struct WeeklyReportView: View {
    @Environment(AppStore.self) var store
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Metrics.sectionSpacing) { // 24
                WeeklyInsightCard()
                
                // 深度建议
                VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
                    HStack {
                        Image(systemName: DesignSystem.Icons.concept)
                            .foregroundStyle(.orange)
                        Text(L10n.Dashboard.insight.tips.title)
                            .font(.headline)
                    }
                    
                    Text(L10n.Dashboard.insight.tips.content)
                        .font(.subheadline)
                        .lineSpacing(SystemSpacing.small) // 6
                        .foregroundStyle(.appSecondary)
                        .padding(DesignSystem.loosePadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.containerBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius)) // 16
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                                .stroke(DesignSystem.containerBorder, lineWidth: DesignSystem.borderWidth)
                        )
                }
                .padding(.top, SystemSpacing.elementLarge) // 10
                
                // 底部占位，增加留白感
                Spacer(minLength: DesignSystem.Metrics.iconBoxSize) // 40
            }
            .padding(DesignSystem.loosePadding)
        }
        .background(PageBackgroundView(accentColor: .purple))
        .appSubPageToolbar(title: L10n.Common.Sidebar.weeklyInsight)
    }
}

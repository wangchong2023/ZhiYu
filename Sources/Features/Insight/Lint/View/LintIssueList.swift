//
//  LintIssueList.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：知识健康检查面板 — 健康得分仪表盘 / 指标网格 / 问题分组列表。
//

import SwiftUI
import UFPCore

// MARK: - 健康检查板块

// 进度环描边宽度（组件特定值）
private let progressRingLineWidth: CGFloat = 10

// 健康检查业务阈值常量
private enum InsightBusinessConstants {
    /// 健康分"差"档上限阈值
    static let healthPoorThreshold = 50
}

/// 知识治理健康检查总面板：包含仪表盘头部、指标网格与问题分组列表
struct LintHealthCheckSection: View {
    @Environment(AppStore.self) var store
    let aiStore: AIWorkflowStore
    let healthColor: Color
    let onRun: () -> Void

    var formattedLastDate: String {
        if let date = aiStore.lastLintDate {
            return date.formatted(as: Date.AppFormatStyle.slashDetailed)
        }
        return L10n.Lint.lastCheckNever
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.giant) {
                // 1. Dashboard Header
                healthDashboardHeader
                    .padding(.top)

                // 2. Metrics Grid
                metricsGrid

                // 3. Issue List (如果存在问题)
                if !aiStore.lintIssues.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.medium) {
                        Text(L10n.Lint.detailIssues)
                            .font(.headline)
                            .padding(.horizontal, DesignSystem.huge)

                        VStack(alignment: .leading, spacing: 0) {
                            issueSection(title: L10n.Lint.errors(aiStore.lintIssues.filter { $0.severity == .error }.count),
                                         issues: aiStore.lintIssues.filter { $0.severity == .error },
                                         icon: DesignSystem.Icons.errorCircle, color: .red)

                            issueSection(title: L10n.Lint.warnings(aiStore.lintIssues.filter { $0.severity == .warning }.count),
                                         issues: aiStore.lintIssues.filter { $0.severity == .warning },
                                         icon: DesignSystem.Icons.warning, color: .orange)

                            issueSection(title: L10n.Lint.tips(aiStore.lintIssues.filter { $0.severity == .info }.count),
                                         issues: aiStore.lintIssues.filter { $0.severity == .info },
                                         icon: DesignSystem.Icons.info, color: .blue)
                        }
                        .appContainer(padding: true)
                        .padding(.horizontal, DesignSystem.huge)
                    }
                }
            }
            .padding(.bottom, DesignSystem.wide)
        }
    }

    // MARK: - Dashboard 头部

    private var healthDashboardHeader: some View {
        VStack(spacing: DesignSystem.wide) {
            ZStack {
                // 上次检查时间展示在左上角
                VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
                    Text(L10n.Lint.lastCheckTitle)
                        .font(.system(size: DesignSystem.microFontSize, weight: .bold))
                        .foregroundStyle(.appText)
                        .padding(.leading, DesignSystem.tiny)

                    VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                        Text(formattedLastDate)
                            .font(.system(size: DesignSystem.microFontSize, design: .monospaced))
                            .foregroundStyle(.appText)
                    }
                    .appContainer(padding: false)
                    .padding(DesignSystem.small)
                }
                .padding(.leading, DesignSystem.huge)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(healthColor.opacity(DesignSystem.Opacity.light), lineWidth: progressRingLineWidth)
                            .frame(width: DesignSystem.Domain.Lint.chartSize, height: DesignSystem.Domain.Lint.chartSize)

                        // 进度环
                        Circle()
                            .trim(from: 0, to: CGFloat(aiStore.lintScore) / 100.0)
                            .stroke(
                                LinearGradient(colors: [healthColor.opacity(DesignSystem.Opacity.dim), healthColor], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: progressRingLineWidth, lineCap: .round)
                            )
                            .frame(width: DesignSystem.Domain.Lint.chartSize, height: DesignSystem.Domain.Lint.chartSize)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("\(aiStore.lintScore)")
                                .font(.system(size: DesignSystem.Domain.Lint.scoreFontSize, weight: .bold, design: .rounded))
                                .foregroundStyle(.appText)

                            Text(aiStore.healthLevel.title)
                                .font(.system(size: DesignSystem.subheadlineFontSize, weight: .bold))
                                .foregroundStyle(healthColor)
                        }
                    }
                    Spacer()
                }

                // 评分标准展示在右下角
                VStack(alignment: .trailing, spacing: DesignSystem.tiny) {
                    let ranges = [
                        (L10n.Lint.healthExcellent, "90-100"),
                        (L10n.Lint.healthGood, "70-89"),
                        (L10n.Lint.healthFair, "50-69"),
                        (L10n.Lint.healthPoor, "< \(InsightBusinessConstants.healthPoorThreshold)")
                    ]

                    ForEach(ranges, id: \.1) { label, range in
                        HStack(spacing: DesignSystem.small) {
                            Text(label)
                                .font(.system(size: DesignSystem.microFontSize, weight: .bold))
                                .frame(width: DesignSystem.IconSize.large, alignment: .trailing)
                            Text(range)
                                .font(.system(size: DesignSystem.microFontSize, design: .monospaced))
                                .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.prominent))
                                .frame(width: DesignSystem.IconSize.xxlarge, alignment: .leading)
                        }
                    }
                }
                .appContainer(padding: false)
                .padding(DesignSystem.small)
                .padding(.trailing, DesignSystem.standardPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(height: ComponentSpacing.chartHeightCompact)
        }
    }

    // MARK: - 指标网格

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: DesignSystem.standardPadding), GridItem(.flexible(), spacing: DesignSystem.standardPadding)], spacing: DesignSystem.standardPadding) {
            metricCard(title: L10n.Lint.metricPages,
                       value: "\(store.pages.count)",
                       icon: DesignSystem.Icons.documentFill,
                       color: .blue)

            metricCard(title: L10n.Lint.metricBroken,
                       value: "\(store.brokenLinkCount)",
                       icon: DesignSystem.Icons.link,
                       color: .red)

            metricCard(title: L10n.Lint.metricOrphans,
                       value: "\(store.orphanPageCount)",
                       icon: DesignSystem.Icons.orphanPage,
                       color: .orange)

            metricCard(title: L10n.Lint.metricLinks,
                       value: "\(store.totalConnectionCount)",
                       icon: DesignSystem.Icons.network,
                       color: .appAccent)
        }
        .padding(.horizontal, DesignSystem.huge)
    }

    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(DesignSystem.Opacity.glass))
                        .frame(width: ComponentSpacing.huge, height: ComponentSpacing.huge)
                    Image(systemName: icon)
                        .font(.system(size: DesignSystem.subheadlineFontSize, weight: .bold))
                        .foregroundColor(color)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(title)
                    .font(.system(size: DesignSystem.captionFontSize, weight: .medium))
                    .foregroundColor(.appSecondary)

                Text(value)
                    .font(.system(size: DesignSystem.displayFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.appText)
            }
        }
        .padding(DesignSystem.standardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appContainer(background: Color.appCard, cornerRadius: DesignSystem.Metrics.dashboardRadius, padding: false)
        .shadow(color: .primary.opacity(DesignSystem.Opacity.faint), radius: SystemSpacing.medium, x: 0, y: SystemSpacing.small)
    }

    // MARK: - 问题分组

    private func issueSection(title: String, issues: [LintIssue], icon: String, color: Color) -> some View {
        Group {
            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    HStack {
                        Label(title, systemImage: icon)
                            .font(.subheadline.bold())
                            .foregroundStyle(color)
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.tiny)

                    VStack(spacing: 0) {
                        ForEach(issues) { issue in
                            LintIssueRow(issue: issue)
                                .padding(.horizontal)
                                .padding(.vertical, DesignSystem.small)

                            if issue.id != issues.last?.id {
                                Divider().padding(.leading, ComponentSpacing.ultra)
                            }
                        }
                    }
                    .appContainer(padding: true)
                }
                .padding(.bottom, DesignSystem.small)
            }
        }
    }
}

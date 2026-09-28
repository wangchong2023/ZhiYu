//
//  TaskRoutingRulesView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建任务路由规则详情页面，为开发调试提供细粒度的端云分流策略说明。
//

import SwiftUI
import UFPDesignSystem

/// 任务路由规则子视图
public struct TaskRoutingRulesView: View {

    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                // 顶层规则说明
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                    Text(L10n.ModelManager.Routing.taskRules)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.appText)
                        .padding(.horizontal, DesignTokens.Spacing.small)

                    VStack(spacing: DesignTokens.Spacing.small) {
                        routingRuleRow(icon: "lock.fill", iconColor: Color.theme.red, task: L10n.ModelManager.Routing.taskSemanticChunking, rule: L10n.ModelManager.Routing.strategyForceLocal)
                        routingRuleRow(icon: "lock.fill", iconColor: Color.theme.red, task: L10n.ModelManager.Routing.taskLinkDiscovery, rule: L10n.ModelManager.Routing.strategyForceLocal)
                        routingRuleRow(icon: "arrow.triangle.branch", iconColor: Color.theme.blue, task: L10n.ModelManager.Routing.taskSynthesis, rule: L10n.ModelManager.Routing.strategySmartRouting)
                        routingRuleRow(icon: "arrow.triangle.branch", iconColor: Color.theme.blue, task: L10n.ModelManager.Routing.taskChat, rule: L10n.ModelManager.Routing.strategySmartRouting)
                        routingRuleRow(icon: "arrow.triangle.branch", iconColor: Color.theme.blue, task: L10n.ModelManager.Routing.taskTagGeneration, rule: L10n.ModelManager.Routing.strategySmartRouting)
                    }
                    .cardStyle(horizontalPadding: DesignTokens.Spacing.standardPadding, verticalPadding: DesignTokens.Spacing.standardPadding)
                }
            }
            .padding(DesignTokens.Spacing.medium)
        }
        .background(themeManager.pageBackground().ignoresSafeArea())
        .navigationTitle(L10n.ModelManager.Routing.taskRules)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func routingRuleRow(icon: String, iconColor: Color, task: String, rule: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: icon).font(.caption).foregroundStyle(iconColor).frame(width: DesignTokens.Spacing.titleIconSize)
            Text(task).font(.subheadline).foregroundStyle(.appText)
            Spacer()
            Image(systemName: DesignTokens.Icons.arrowRight).font(.caption2).foregroundStyle(.appSecondary)
            Text(rule).font(.caption.weight(.medium)).foregroundStyle(.appAccent)
        }
        .padding(.vertical, DesignTokens.Spacing.small).padding(.horizontal, DesignTokens.Spacing.medium)
        .background(Color.appBackground.opacity(DesignTokens.Opacity.soft))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small))
    }
}

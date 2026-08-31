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

/// 任务路由规则子视图
public struct TaskRoutingRulesView: View {

    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.large) {
                // 顶层规则说明
                VStack(alignment: .leading, spacing: DesignSystem.small) {
                    Text(L10n.ModelManager.Routing.taskRules)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.appText)
                        .padding(.horizontal, DesignSystem.small)

                    VStack(spacing: DesignSystem.small) {
                        routingRuleRow(icon: "lock.fill", iconColor: Color.theme.red, task: L10n.ModelManager.Routing.taskSemanticChunking, rule: L10n.ModelManager.Routing.strategyForceLocal)
                        routingRuleRow(icon: "lock.fill", iconColor: Color.theme.red, task: L10n.ModelManager.Routing.taskLinkDiscovery, rule: L10n.ModelManager.Routing.strategyForceLocal)
                        routingRuleRow(icon: "arrow.triangle.branch", iconColor: Color.theme.blue, task: L10n.ModelManager.Routing.taskSynthesis, rule: L10n.ModelManager.Routing.strategySmartRouting)
                        routingRuleRow(icon: "arrow.triangle.branch", iconColor: Color.theme.blue, task: L10n.ModelManager.Routing.taskChat, rule: L10n.ModelManager.Routing.strategySmartRouting)
                        routingRuleRow(icon: "arrow.triangle.branch", iconColor: Color.theme.blue, task: L10n.ModelManager.Routing.taskTagGeneration, rule: L10n.ModelManager.Routing.strategySmartRouting)
                    }
                    .padding()
                    .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius))
                }
            }
            .padding(DesignSystem.medium)
        }
        .background(themeManager.pageBackground().ignoresSafeArea())
        .navigationTitle(L10n.ModelManager.Routing.taskRules)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func routingRuleRow(icon: String, iconColor: Color, task: String, rule: String) -> some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: icon).font(.caption).foregroundStyle(iconColor).frame(width: DesignSystem.titleIconSize)
            Text(task).font(.subheadline).foregroundStyle(.appText)
            Spacer()
            Image(systemName: DesignSystem.Icons.arrowRight).font(.caption2).foregroundStyle(.appSecondary)
            Text(rule).font(.caption.weight(.medium)).foregroundStyle(.appAccent)
        }
        .padding(.vertical, DesignSystem.small).padding(.horizontal, DesignSystem.medium)
        .background(Color.appBackground.opacity(DesignSystem.Opacity.soft))
        .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
    }
}

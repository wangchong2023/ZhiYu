//
//  InsightEmptyState.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Insight 模块通用空状态视图，消除 LogView、TagCloudSubViews、KnowledgeDashboardView、
//  LintRuleManager 中重复的"图标 + 主标题 + 副标题"空状态占位布局。
//

import SwiftUI

/// [L3] 表现层：通用空状态视图
///
/// 统一封装图标 + 主标题 + 副标题的垂直居中空状态布局，
/// 通过 `icon`、`title`、`hint` 参数适配不同场景（无日志、无标签、无数据、无 AI 建议）。
struct InsightEmptyState: View {
    let icon: String
    let title: String
    var hint: String?
    var iconSize: CGFloat = DesignSystem.iconHuge
    var iconColor: Color = .appSecondary
    var hintOpacity: Double = DesignSystem.subtleOpacity
    var verticalPadding: CGFloat?

    var body: some View {
        VStack(spacing: DesignSystem.medium) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)

            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.appSecondary.opacity(hintOpacity))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .modifier(OptionalVerticalPadding(padding: verticalPadding))
    }
}

/// 可选垂直内边距修饰符
private struct OptionalVerticalPadding: ViewModifier {
    let padding: CGFloat?

    func body(content: Content) -> some View {
        if let padding {
            content.padding(.vertical, padding)
        } else {
            content
        }
    }
}

//
//  InsightSectionHeader.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Insight 模块通用章节标题，消除 ConceptDetailBodyView、EntityDetailBodyView、
//  ComparisonDetailBodyView、SourceDetailBodyView、PageDetailMetadataSection 中重复的
//  "图标 + 标题"章节头布局。
//

import SwiftUI

/// [L3] 表现层：通用章节标题
///
/// 统一封装 `Label(title, systemImage:)` + `.font(.subheadline.bold())` + `.foregroundStyle(.appSecondary)`，
/// 消除 4 个 DetailBodyView 与 PageDetailMetadataSection 中重复的章节标题修饰符链。
struct InsightSectionHeader: View {
    let title: String
    let icon: String
    var color: Color = .appSecondary

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.bold())
            .foregroundStyle(color)
    }
}

extension View {
    /// 应用 AI 推荐卡片的统一渐变样式
    func aiRecommendationCardStyle(verticalPadding: CGFloat = DesignSystem.small) -> some View {
        self
            .accentGradientCardStyle(
                cornerRadius: DesignSystem.largeRadius,
                backgroundOpacity: DesignSystem.Opacity.atomic,
                borderWidth: SystemStroke.divider,
                borderOpacity: DesignSystem.Opacity.medium
            )
            .padding(.vertical, verticalPadding)
    }

    /// 应用 Insight 大纲卡片的标准样式
    func insightOutlineCardStyle() -> some View {
        self
            .cardStyle(
                horizontalPadding: DesignSystem.standardPadding,
                verticalPadding: DesignSystem.standardPadding,
                backgroundOpacity: DesignSystem.Opacity.subtle,
                cornerRadius: DesignSystem.standardRadius
            )
    }
}

/// [L3] 表现层：Dashboard 章节标题
///
/// 统一封装 Dashboard 中"图标 + 标题 + 可选信息按钮 + Spacer"的章节头布局，
/// 消除 densityChartSection 与 hotTopicsSection 中的重复标题链。
struct InsightDashboardSectionTitle: View {
    let icon: String
    let title: String
    var infoAction: (() -> Void)?

    var body: some View {
        HStack(spacing: DesignSystem.tiny) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.appAccent)
            Text(title)
                .font(.headline)
            if let infoAction {
                Button(action: infoAction) {
                    Image(systemName: DesignSystem.Icons.info)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

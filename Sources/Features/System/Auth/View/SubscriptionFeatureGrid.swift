//
//  SubscriptionFeatureGrid.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：订阅套餐功能对比网格，展示 Lite/Pro 权益逐项对照。
//

import SwiftUI

/// 订阅套餐权益对比网格组件
@MainActor
struct SubscriptionFeatureGrid: View {
    let liteFeatures: [PlanFeature]
    let proFeatures: [PlanFeature]

    var body: some View {
        AppCard {
            VStack(spacing: 0) {
                // 标题行
                HStack(alignment: .center) {
                    Color.clear
                        .frame(maxWidth: .infinity)

                    headerTitle(L10n.Auth.litePlan, color: .appSecondary)

                    verticalDivider(maxHeight: Spacing.iconSmall)

                    headerTitle(L10n.Auth.proPlan, color: .appAccent)
                }
                .cellPadding()

                AppDivider()

                // 权益对比行
                // Bug #105 修复：Divider 判断用 min(count) 而非 liteFeatures.count，
                // 避免两个数组长度不一致时 Divider 显示错误。
                let displayCount = min(liteFeatures.count, proFeatures.count)
                ForEach(0..<displayCount, id: \.self) { i in
                    featureRow(lite: liteFeatures[i], pro: proFeatures[i])
                    if i < displayCount - 1 {
                        AppDivider().padding(.leading, DesignSystem.large)
                    }
                }
            }
        }
    }

    private func featureRow(lite: PlanFeature, pro: PlanFeature) -> some View {
        HStack(alignment: .center) {
            // 功能名
            HStack(spacing: DesignSystem.small) {
                Image(systemName: pro.icon)
                    .foregroundStyle(.appAccent)
                    .frame(width: DesignSystem.IconSize.small)
                Text(lite.title)
                    .font(.caption)
                    .foregroundStyle(.appText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Lite 值
            Text(lite.value)
                .font(.caption.bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(.appSecondary)

            verticalDivider(maxHeight: DesignSystem.medium)

            // Pro 值
            Text(pro.value)
                .font(.caption.bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(.appAccent)
        }
        .cellPadding()
    }

    /// 垂直分隔线，消除表头与数据行的 Rectangle 重复
    private func verticalDivider(maxHeight: CGFloat) -> some View {
        Rectangle()
            .fill(Color.appBorder.opacity(DesignSystem.secondaryOpacity))
            .frame(width: DesignSystem.Metrics.dividerThickness)
            .padding(.horizontal, SystemSpacing.tiny)
            .frame(maxHeight: maxHeight)
    }

    /// 单元格内边距，消除表头与数据行的 padding 重复
    private func cellPadding() -> some View {
        self
            .padding(.horizontal, DesignSystem.medium)
            .padding(.vertical, DesignSystem.small)
    }

    /// 表头标题文本，消除 Lite/Pro 表头的 Text 样式重复
    private func headerTitle(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.subheadline.bold())
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundStyle(color)
    }
}

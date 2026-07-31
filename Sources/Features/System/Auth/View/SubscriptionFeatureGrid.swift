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

                    Text(L10n.Auth.litePlan)
                        .font(.subheadline.bold())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundStyle(.appSecondary)

                    Rectangle()
                        .fill(Color.appBorder.opacity(DesignSystem.secondaryOpacity))
                        .frame(width: DesignSystem.Metrics.dividerThickness)
                        .padding(.horizontal, 4)
                        .frame(maxHeight: 24)

                    Text(L10n.Auth.proPlan)
                        .font(.subheadline.bold())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundStyle(.appAccent)
                }
                .padding(.horizontal, DesignSystem.medium)
                .padding(.vertical, DesignSystem.small)

                AppDivider()

                // 权益对比行
                ForEach(0..<min(liteFeatures.count, proFeatures.count), id: \.self) { i in
                    featureRow(lite: liteFeatures[i], pro: proFeatures[i])
                    if i < liteFeatures.count - 1 {
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

            Rectangle()
                .fill(Color.appBorder.opacity(DesignSystem.secondaryOpacity))
                .frame(width: DesignSystem.Metrics.dividerThickness)
                .padding(.horizontal, 4)
                .frame(maxHeight: 16)

            // Pro 值
            Text(pro.value)
                .font(.caption.bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(.appAccent)
        }
        .padding(.horizontal, DesignSystem.medium)
        .padding(.vertical, DesignSystem.small)
    }
}

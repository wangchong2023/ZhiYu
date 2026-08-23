//
//  SubscriptionPlanCard.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：订阅套餐卡片组件，展示 Lite/Pro 套餐对比与计费周期选择器。
//

import SwiftUI

/// 订阅套餐卡片对比组件（Lite vs Pro）
@MainActor
struct SubscriptionPlanCard: View {
    let selectedCycle: BillingCycle
    let onCycleChange: (BillingCycle) -> Void

    var body: some View {
        VStack(spacing: DesignSystem.medium) {
            cycleTabSelector
            tierCardsSection
        }
    }

    // MARK: - 周期选择器

    private var cycleTabSelector: some View {
        HStack(spacing: DesignSystem.medium) {
            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                onCycleChange(.monthly)
            }) {
                VStack(spacing: SystemSpacing.atomic) {
                    Text(L10n.Auth.monthly)
                        .font(.subheadline.bold())
                    Text(L10n.Auth.priceMonthlyPro)
                        .font(.system(size: 10)) // Dynamic Type
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SystemSpacing.element)
                .foregroundStyle(selectedCycle == .monthly ? .appAccent : .appSecondary)
            }
            .buttonStyle(.plain)
            .background(Color.appCard.opacity(SystemOpacity.glassStrong))
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: SystemRadius.card)
                    .stroke(
                        selectedCycle == .monthly
                            ? AnyShapeStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color.appBorder.opacity(DesignSystem.Opacity.light)),
                        lineWidth: selectedCycle == .monthly ? 2 : 1
                    )
            )

            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                onCycleChange(.yearly)
            }) {
                VStack(spacing: SystemSpacing.atomic) {
                    HStack(spacing: SystemSpacing.tiny) {
                        Text(L10n.Auth.yearly)
                            .font(.subheadline.bold())
                        Text(L10n.Auth.save20Percent)
                            .font(.system(size: 8, weight: .bold)) // Dynamic Type
                            .foregroundStyle(.white)
                            .padding(.horizontal, SystemSpacing.tiny)
                            .padding(.vertical, SystemSpacing.divider)
                            .background(Color.theme.blue)
                            .clipShape(Capsule())
                    }
                    Text(L10n.Auth.priceYearlyPro)
                        .font(.system(size: 10)) // Dynamic Type
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SystemSpacing.element)
                .foregroundStyle(selectedCycle == .yearly ? .appAccent : .appSecondary)
            }
            .buttonStyle(.plain)
            .background(Color.appCard.opacity(SystemOpacity.glassStrong))
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: SystemRadius.card)
                    .stroke(
                        selectedCycle == .yearly
                            ? AnyShapeStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color.appBorder.opacity(DesignSystem.Opacity.light)),
                        lineWidth: selectedCycle == .yearly ? 2 : 1
                    )
            )
        }
    }

    // MARK: - 套餐卡片对比

    private var tierCardsSection: some View {
        HStack(spacing: DesignSystem.medium) {
            // Lite Card
            VStack(alignment: .leading, spacing: SystemSpacing.element) {
                HStack {
                    Image(systemName: "lightbulb")
                        .font(.title3)
                        .foregroundStyle(.appSecondary)
                        .frame(width: DesignSystem.Timeline.iconCircleSize, height: DesignSystem.Timeline.iconCircleSize)
                        .background(Color.appBorder.opacity(DesignSystem.Opacity.subtle))
                        .clipShape(Circle())

                    Spacer()

                    Text("Lite")
                        .font(.system(size: 9, weight: .bold)) // Dynamic Type
                        .foregroundStyle(.appSecondary)
                        .padding(.horizontal, SystemSpacing.small)
                        .padding(.vertical, SystemSpacing.atomic)
                        .overlay(
                            Capsule().stroke(Color.appBorder, lineWidth: SystemStroke.divider)
                        )
                }
                Text(L10n.Auth.priceMonthlyLite)
                    .font(.title3.bold())
                    .foregroundStyle(.appText)

                Text(L10n.Auth.litePlanDesc)
                    .font(.system(size: 10)) // Dynamic Type
                    .foregroundStyle(.appSecondary)
                    .lineLimit(2)
            }
            .padding(DesignSystem.medium)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.appCard.opacity(SystemOpacity.glassStrong))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.largeRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.largeRadius)
                    .stroke(Color.appBorder.opacity(DesignSystem.Opacity.prominent), lineWidth: SystemStroke.emphasis)
            )

            // Pro Card
            VStack(alignment: .leading, spacing: SystemSpacing.element) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: DesignSystem.Timeline.iconCircleSize, height: DesignSystem.Timeline.iconCircleSize)
                        .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(Circle())

                    Spacer()

                    Text(L10n.Auth.proPlan)
                        .font(.system(size: 9, weight: .bold)) // Dynamic Type
                        .foregroundStyle(.white)
                        .padding(.horizontal, SystemSpacing.small)
                        .padding(.vertical, SystemSpacing.atomic)
                        .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                        .clipShape(Capsule())
                }
                let proPriceStr: String = selectedCycle == .monthly ? L10n.Auth.priceMonthlyPro : L10n.Auth.priceMonthlyProEquivalent

                Text(proPriceStr)
                    .font(.title3.bold())
                    .foregroundStyle(.appAccent)

                Text(L10n.Auth.proPlanDesc)
                    .font(.system(size: 10)) // Dynamic Type
                    .foregroundStyle(.appSecondary)
                    .lineLimit(2)
            }
            .padding(DesignSystem.medium)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.appCard.opacity(SystemOpacity.glassHeavy))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.largeRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.largeRadius)
                    .stroke(
                        LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: SystemStroke.accent
                    )
            )
            .shadow(color: .purple.opacity(DesignSystem.Opacity.shadow), radius: SystemShadow.radiusMedium, x: SystemShadow.offsetNone, y: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

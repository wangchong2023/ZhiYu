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

    /// Pro 套餐统一的紫蓝渐变，消除多处 LinearGradient 重复
    private static let proGradient = LinearGradient(colors: [Color.theme.purple, Color.theme.blue], startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        VStack(spacing: DesignSystem.medium) {
            cycleTabSelector
            tierCardsSection
        }
    }

    // MARK: - 周期选择器

    private var cycleTabSelector: some View {
        HStack(spacing: DesignSystem.medium) {
            cycleButton(
                cycle: .monthly,
                title: L10n.Auth.monthly,
                price: L10n.Auth.priceMonthlyPro,
                badge: nil
            )
            cycleButton(
                cycle: .yearly,
                title: L10n.Auth.yearly,
                price: L10n.Auth.priceYearlyPro,
                badge: L10n.Auth.save20Percent
            )
        }
    }

    /// 通用周期按钮，消除月付/年付按钮的 Button+VStack+cycleButtonContent+cycleButtonStyle 重复
    @ViewBuilder
    private func cycleButton(
        cycle: BillingCycle,
        title: String,
        price: String,
        badge: String?
    ) -> some View {
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            onCycleChange(cycle)
        }) {
            VStack(spacing: SystemSpacing.atomic) {
                if let badge {
                    HStack(spacing: SystemSpacing.tiny) {
                        Text(title)
                            .font(.subheadline.bold())
                        Text(badge)
                            .font(.system(size: SystemFontSize.nano, weight: .bold)) // Dynamic Type
                            .foregroundStyle(.white)
                            .padding(.horizontal, SystemSpacing.tiny)
                            .padding(.vertical, SystemSpacing.divider)
                            .background(Color.theme.blue)
                            .clipShape(Capsule())
                    }
                } else {
                    Text(title)
                        .font(.subheadline.bold())
                }
                Text(price)
                    .font(.system(size: SystemFontSize.micro)) // Dynamic Type
            }
            .cycleButtonContent(isSelected: selectedCycle == cycle)
        }
        .cycleButtonStyle(isSelected: selectedCycle == cycle)
    }

    /// 周期按钮内容容器样式，消除月付/年付按钮的 frame+padding+foregroundStyle 重复
    private func cycleButtonContent(isSelected: Bool) -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(.vertical, SystemSpacing.element)
            .foregroundStyle(isSelected ? .appAccent : .appSecondary)
    }

    /// 周期按钮样式，消除月付/年付按钮的重复修饰符链
    private func cycleButtonStyle(isSelected: Bool) -> some View {
        self
            .buttonStyle(.plain)
            .background(Color.appCard.opacity(SystemOpacity.glassStrong))
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: SystemRadius.card)
                    .stroke(
                        isSelected
                            ? AnyShapeStyle(Self.proGradient)
                            : AnyShapeStyle(Color.appBorder.opacity(DesignSystem.Opacity.light)),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
    }

    /// 套餐描述文本样式，消除 Lite/Pro Card 的重复
    private func planDescStyle() -> some View {
        self
            .font(.system(size: SystemFontSize.micro))
            .foregroundStyle(.appSecondary)
            .lineLimit(2)
    }

    /// 套餐卡片容器基础布局，消除 Lite/Pro Card 的 padding+frame 重复
    private func planCardContainerBase() -> some View {
        self
            .padding(DesignSystem.medium)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - 套餐卡片对比

    private var tierCardsSection: some View {
        HStack(spacing: DesignSystem.medium) {
            // Lite Card
            VStack(alignment: .leading, spacing: SystemSpacing.element) {
                HStack {
                    Image(systemName: DesignSystem.Icons.lightbulb)
                        .font(.title3)
                        .foregroundStyle(.appSecondary)
                        .frame(width: DesignSystem.Timeline.iconCircleSize, height: DesignSystem.Timeline.iconCircleSize)
                        .background(Color.appBorder.opacity(DesignSystem.Opacity.subtle))
                        .clipShape(Circle())

                    Spacer()

                    Text(FeatureConstants.MockData.litePlanName)
                        .font(.system(size: SystemFontSize.nano, weight: .bold)) // Dynamic Type
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
                    .planDescStyle()
            }
            .planCardContainerBase()
            .background(Color.appCard.opacity(SystemOpacity.glassStrong))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.largeRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.largeRadius)
                    .stroke(Color.appBorder.opacity(DesignSystem.Opacity.prominent), lineWidth: SystemStroke.emphasis)
            )

            // Pro Card
            VStack(alignment: .leading, spacing: SystemSpacing.element) {
                HStack {
                    Image(systemName: DesignSystem.Icons.boltFill)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: DesignSystem.Timeline.iconCircleSize, height: DesignSystem.Timeline.iconCircleSize)
                        .background(Self.proGradient)
                        .clipShape(Circle())

                    Spacer()

                    Text(L10n.Auth.proPlan)
                        .font(.system(size: SystemFontSize.nano, weight: .bold)) // Dynamic Type
                        .foregroundStyle(.white)
                        .padding(.horizontal, SystemSpacing.small)
                        .padding(.vertical, SystemSpacing.atomic)
                        .background(LinearGradient(colors: [Color.theme.purple, Color.theme.blue], startPoint: .leading, endPoint: .trailing))
                        .clipShape(Capsule())
                }
                let proPriceStr: String = selectedCycle == .monthly ? L10n.Auth.priceMonthlyPro : L10n.Auth.priceMonthlyProEquivalent

                Text(proPriceStr)
                    .font(.title3.bold())
                    .foregroundStyle(.appAccent)

                Text(L10n.Auth.proPlanDesc)
                    .planDescStyle()
            }
            .planCardContainerBase()
            .background(Color.appCard.opacity(SystemOpacity.disabled))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.largeRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.largeRadius)
                    .stroke(
                        Self.proGradient,
                        lineWidth: SystemStroke.heavy
                    )
            )
            .shadow(color: .purple.opacity(DesignSystem.Opacity.shadow), radius: SystemShadow.radiusMedium, x: 0, y: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

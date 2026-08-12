//
//  SubscriptionPlanView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：订阅套餐页面容器，组合套餐卡片、功能对比网格与购买流程子视图。
//

import SwiftUI
import StoreKit

/// 订阅周期
enum BillingCycle {
    case monthly
    case yearly
}

/// 套餐权益条目
struct PlanFeature {
    let icon: String
    let title: String
    let value: String
}

@MainActor
public struct SubscriptionPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @Environment(ThemeManager.self) var themeManager

    private enum Constants {
        static let barHeight: CGFloat = 6
        static let popoverWidth: CGFloat = 280
    }

    // MARK: - 状态变量
    @State private var isPurchasing = false
    @State private var isUpgradeSuccess = false
    @State private var selectedCycle: BillingCycle = .yearly
    @State private var errorMessage: String?
    @State private var isQuotaExpanded = false

    // MARK: - 权益对比数据

    private var liteFeatures: [PlanFeature] {
        [
            PlanFeature(icon: "books.vertical", title: L10n.Auth.Feature.vaults, value: L10n.Auth.Feature.vaultsLiteValue),
            PlanFeature(icon: "doc.text", title: L10n.Auth.Feature.pages, value: L10n.Auth.Feature.pagesLiteValue),
            PlanFeature(icon: "puzzlepiece", title: L10n.Auth.Feature.plugins, value: L10n.Auth.Feature.pluginsLiteValue),
            PlanFeature(icon: "sparkle", title: L10n.Auth.Feature.aiSynth, value: L10n.Auth.Feature.aiSynthLiteValue),
            PlanFeature(icon: "lock.shield", title: L10n.Auth.Feature.privacySecurity, value: L10n.Auth.Feature.privacySecurityLiteValue)
        ]
    }

    private var proFeatures: [PlanFeature] {
        [
            PlanFeature(icon: "books.vertical.fill", title: L10n.Auth.Feature.vaults, value: L10n.Auth.Feature.vaultsProValue),
            PlanFeature(icon: "doc.text.fill", title: L10n.Auth.Feature.pages, value: L10n.Auth.Feature.pagesProValue),
            PlanFeature(icon: "puzzlepiece.fill", title: L10n.Auth.Feature.plugins, value: L10n.Auth.Feature.pluginsProValue),
            PlanFeature(icon: "sparkles", title: L10n.Auth.Feature.aiSynth, value: L10n.Auth.Feature.aiSynthProValue),
            PlanFeature(icon: "lock.shield.fill", title: L10n.Auth.Feature.privacySecurity, value: L10n.Auth.Feature.privacySecurityProValue)
        ]
    }

    public init() {}

    public var body: some View {
        ZStack {
            themeManager.pageBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.large) {
                    if !(authService.currentUser?.isPro ?? false) && !isUpgradeSuccess {
                        // 标题
                        VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                            Text(L10n.Auth.upgradeToPro)
                                .font(.headline.bold())
                                .foregroundStyle(.appText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // 套餐卡片对比（含周期切换器）
                        SubscriptionPlanCard(
                            selectedCycle: selectedCycle,
                            onCycleChange: { selectedCycle = $0 }
                        )

                        // 权益对比网格
                        SubscriptionFeatureGrid(
                            liteFeatures: liteFeatures,
                            proFeatures: proFeatures
                        )

                        // 错误信息展示
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, DesignSystem.medium)
                        }

                        // 购买流程
                        SubscriptionPurchaseFlow(
                            isPurchasing: $isPurchasing,
                            isUpgradeSuccess: $isUpgradeSuccess,
                            errorMessage: $errorMessage,
                            selectedCycle: selectedCycle
                        )
                    } else {
                        successView
                    }
                }
                .padding(DesignSystem.medium)
            }

            // 全屏购买 Loading 覆盖
            if isPurchasing {
                AppLoadingOverlay(isLoading: isPurchasing, message: L10n.Auth.purchasing)
            }
        }
        .navigationTitle(L10n.Auth.subscription)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { isQuotaExpanded.toggle() }) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.body.bold())
                }
                .popover(isPresented: $isQuotaExpanded) {
                    quotaPopoverContent
                        .presentationCompactAdaptation(.popover)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.Common.done) { dismiss() }
            }
        }
    }

    // MARK: - 配额监控弹窗 (Popover)

    private var quotaPopoverContent: some View {
        VStack(spacing: DesignSystem.medium) {
            Text(L10n.Common.usage)
                .font(.headline.bold())
                .foregroundStyle(.appText)
            
            VStack(spacing: DesignSystem.medium) {
                let vaultsCount = VaultService.shared.vaults.count
                let vaultsMax = authService.currentUser?.maxVaults ?? 2
                glassQuotaCard(title: L10n.Auth.vaultUsage, icon: "books.vertical", current: vaultsCount, max: vaultsMax)

                let pagesCount = VaultService.shared.vaults.reduce(0) { $0 + $1.pageCount }
                let pagesMax = authService.currentUser?.maxPages ?? 1000
                glassQuotaCard(title: L10n.Auth.pagesUsage, icon: "doc.text", current: pagesCount, max: pagesMax)

                let pluginsCount = PluginRegistry.shared.plugins.count
                let pluginsMax = authService.currentUser?.maxPlugins ?? 3
                glassQuotaCard(title: L10n.Auth.pluginsUsage, icon: "puzzlepiece", current: pluginsCount, max: pluginsMax)
            }
            .padding(DesignSystem.medium)
            .background(Color.appCard.opacity(DesignSystem.glassOpacity * 2))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.large))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.large)
                    .stroke(Color.appBorder.opacity(DesignSystem.Opacity.light), lineWidth: 1)
            )
        }
        .padding()
        .frame(width: Constants.popoverWidth)
    }

    private func glassQuotaCard(title: String, icon: String, current: Int, max: Int) -> some View {
        let ratio = CGFloat(min(Double(current) / Double(max), 1.0))
        let isDanger = ratio > 0.9

        return VStack(spacing: DesignSystem.small) {
            HStack {
                HStack(spacing: DesignSystem.tiny) {
                    Image(systemName: icon)
                        .font(.caption2)
                    Text(title)
                        .font(.caption.bold())
                }
                .foregroundStyle(.appSecondary)

                Spacer()

                Text("\(current) / \(max < 999999 ? "\(max)" : "∞")")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(.appText)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appBorder.opacity(DesignSystem.Opacity.light))
                        .frame(height: Constants.barHeight)

                    let barWidth = max > 0 ? geo.size.width * ratio : 0

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isDanger ? [.red, .orange] : [Color.theme.blue, Color.theme.cyan],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: barWidth, height: Constants.barHeight)
                }
            }
            .frame(height: Constants.barHeight)
        }
    }

    // MARK: - 成功卡片

    private var successView: some View {
        AppCard {
            VStack(spacing: DesignSystem.medium) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 48)) // Dynamic Type
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, DesignSystem.medium)

                Text(L10n.Auth.upgradeSuccessTitle)
                    .font(.headline)
                    .foregroundStyle(.appText)

                Text(L10n.Auth.upgradeSuccessMessage)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.medium)
                    .padding(.bottom, DesignSystem.medium)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

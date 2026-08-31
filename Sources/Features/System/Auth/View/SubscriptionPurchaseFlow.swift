//
//  SubscriptionPurchaseFlow.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：订阅购买流程组件，处理 Apple StoreKit 购买、恢复购买与支付验证逻辑。
//

import SwiftUI
import StoreKit

/// 订阅购买流程组件：购买按钮、恢复购买与支付逻辑
@MainActor
struct SubscriptionPurchaseFlow: View {
    @Environment(AuthService.self) private var authService

    @Binding var isPurchasing: Bool
    @Binding var isUpgradeSuccess: Bool
    @Binding var errorMessage: String?
    let selectedCycle: BillingCycle

    private var storeKitService: StoreKitService { StoreKitService.shared }

    var body: some View {
        VStack(spacing: DesignSystem.small) {
            // 购买按钮
            let btnText: String = selectedCycle == .yearly
                ? L10n.Auth.upgradeToProYearly
                : L10n.Auth.upgradeToProMonthly

            AppPrimaryButton(
                title: btnText,
                icon: DesignSystem.Icons.applelogo,
                isLoading: isPurchasing
            ) {
                handleApplePurchase()
            }

            // 恢复购买按钮
            Button(action: {
                Task { await handleRestorePurchases() }
            }) {
                HStack(spacing: DesignSystem.tiny) {
                    if storeKitService.isRestoring {
                        ProgressView()
                            .scaleEffect(DesignSystem.Opacity.light)
                    }
                    Text(storeKitService.isRestoring
                         ? L10n.Auth.restoring
                         : L10n.Auth.restorePurchases)
                        .font(.subheadline)
                        .foregroundStyle(.appAccent)
                }
            }
            .buttonStyle(.plain)
            .disabled(storeKitService.isRestoring || isPurchasing)

            // 恢复结果提示
            if let msg = storeKitService.restoreMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            Text(L10n.Auth.purchaseDisclaimer)
                .font(.caption2)
                .foregroundStyle(.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.large)
        }
        .padding(.vertical, DesignSystem.small)
        .animation(.easeInOut(duration: 0.25), value: storeKitService.restoreMessage)
    }

    // MARK: - 支付逻辑

    private func handleApplePurchase() {
        Task {
            isPurchasing = true
            errorMessage = nil
            let productId = selectedCycle == .monthly
                ? AppConstants.Subscription.monthlyProductId
                : AppConstants.Subscription.yearlyProductId

            do {
                let products = try await Product.products(for: [productId])
                if let product = products.first {
                    let result = try await product.purchase()
                    switch result {
                    case .success(let verification):
                        switch verification {
                        case .verified(let transaction):
                            let receipt = transaction.jsonRepresentation.base64EncodedString()
                            let success = await authService.verifyApplePurchase(
                                productId: productId,
                                receiptData: receipt,
                                orderNo: nil
                            )
                            await transaction.finish()
                            if success {
                                isPurchasing = false
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    isUpgradeSuccess = true
                                }
                                updateSessionToPro()
                                return
                            } else {
                                errorMessage = L10n.Auth.verifyFailed
                            }
                        case .unverified:
                            errorMessage = L10n.Auth.verifyFailed
                        }
                    case .userCancelled:
                        break
                    case .pending:
                        errorMessage = L10n.Auth.purchasePending
                    @unknown default:
                        break
                    }
                    isPurchasing = false
                } else {
                    #if DEBUG
                    try await performMockPurchase()
                    #else
                    errorMessage = L10n.Auth.verifyFailed
                    isPurchasing = false
                    #endif
                }
            } catch {
                #if DEBUG
                // Bug #95 修复：catch 块用 defer 确保 isPurchasing 必定重置，
                // 即使 performMockPurchase 抛错也不会卡在 purchasing 状态。
                defer { isPurchasing = false }
                try? await performMockPurchase()
                #else
                errorMessage = L10n.Auth.verifyFailed
                isPurchasing = false
                #endif
            }
        }
    }

    /// 调用 StoreKitService 触发恢复购买流程
    private func handleRestorePurchases() async {
        let success = await storeKitService.restorePurchases()
        if success {
            if authService.currentUser?.isPro ?? false {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    isUpgradeSuccess = true
                }
            }
        }
    }

    private func performMockPurchase() async throws {
        try await Task.sleep(for: .seconds(1.5))
        isPurchasing = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            isUpgradeSuccess = true
        }
        updateSessionToPro()
        HapticFeedback.shared.trigger(.success)
    }

    private func updateSessionToPro() {
        if let user = authService.currentUser {
            let proQuota = User.DefaultQuotas.proQuota
            let proUser = User(
                id: user.id,
                name: user.name,
                email: user.email,
                phone: user.phone,
                avatarURL: user.avatarURL,
                planKey: PlanKey.pro,
                maxVaults: proQuota.maxVaults,
                maxPages: proQuota.maxPages,
                maxPlugins: proQuota.maxPlugins,
                gender: user.gender,
                birthday: user.birthday
            )
            AuthSession.shared.update(user: proUser)
        }
    }
}

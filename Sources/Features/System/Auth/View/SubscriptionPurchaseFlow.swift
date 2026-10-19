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
import UFPDesignSystem

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
        VStack(spacing: DesignTokens.Spacing.small) {
            // 购买按钮
            let btnText: String = selectedCycle == .yearly
                ? L10n.Auth.upgradeToProYearly
                : L10n.Auth.upgradeToProMonthly

            AppPrimaryButton(
                title: btnText,
                icon: DesignTokens.Icons.applelogo,
                isLoading: isPurchasing
            ) {
                handleApplePurchase()
            }

            // 恢复购买按钮
            Button(action: {
                Task { await handleRestorePurchases() }
            }) {
                HStack(spacing: DesignTokens.Spacing.tiny) {
                    if storeKitService.isRestoring {
                        ProgressView()
                            .scaleEffect(DesignTokens.Opacity.light)
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
                .padding(.horizontal, DesignTokens.Spacing.large)
        }
        .padding(.vertical, DesignTokens.Spacing.small)
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
                            await handleVerifiedTransaction(transaction, productId: productId)
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
                    errorMessage = L10n.Auth.verifyFailed
                    isPurchasing = false
                }
            } catch {
                errorMessage = L10n.Auth.verifyFailed
                isPurchasing = false
            }
        }
    }

    /// 处理已通过苹果校验的交易：仅验证成功后才 finish，失败时入队指数退避重试
    private func handleVerifiedTransaction(_ transaction: StoreKit.Transaction, productId: String) async {
        let receipt = transaction.jsonRepresentation.base64EncodedString()
        let success = await authService.verifyApplePurchase(
            productId: productId,
            receiptData: receipt,
            orderNo: nil
        )
        if success {
            // 仅在验证成功后才 finish 交易，避免 StoreKit 判定交易已完成导致无法重试
            await transaction.finish()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isUpgradeSuccess = true
            }
            updateSessionToPro()
        } else {
            // 验证失败不 finish：保留交易供 StoreKit 下次重推，并主动入队指数退避重试
            await PaymentRetryQueue.shared.enqueue(
                productId: productId,
                receiptData: receipt,
                transactionId: String(transaction.id),
                orderNo: nil
            )
            errorMessage = L10n.Auth.verifyFailed
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

    private func updateSessionToPro() {
        if let user = authService.currentUser {
            let proQuota = User.DefaultQuotas.proQuota
            let proUser = user.withPlan(
                planKey: PlanKey.pro,
                maxVaults: proQuota.maxVaults,
                maxPages: proQuota.maxPages,
                maxPlugins: proQuota.maxPlugins
            )
            AuthSession.shared.update(user: proUser)
        }
    }
}

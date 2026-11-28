//
//  StoreKitService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层 - Auth 子域
//  核心职责：
//    1. 在 App 整个生命周期内维护 StoreKit 2 Transaction.updates 持久监听任务。
//       苹果要求：若不监听此流，家庭共享购买、订阅续费、后台恢复均无法触发本地权益更新。
//    2. 提供 restorePurchases() 接口，调用 AppStore.sync() 触发票据验证，
//       满足 App Store 审核要求（§3.1.1 订阅型 App 必须提供恢复购买入口）。
//    3. 监听到订阅过期时，自动将本地用户降级为 Free 配额，防止权益残留。
//

import Foundation
import StoreKit
import Observation

/// StoreKit 2 服务
///
/// - 生命周期：由 `AppEnvironment.init()` 调用 `StoreKitService.shared.startListening()`
///   启动持久 Task，随 App 进程存活。
/// - 线程安全：`@MainActor` 保证所有权益变更在主线程更新 `AuthSession`。
@MainActor
@Observable
public final class StoreKitService {
    
    // MARK: - 单例
    
    /// 全局单例
    @MainActor public static let shared = StoreKitService()
    
    // MARK: - 状态属性
    
    /// 是否正在恢复购买
    public var isRestoring: Bool = false
    
    /// 最近一次恢复购买的结果消息（nil = 无消息）
    public var restoreMessage: String?
    
    // MARK: - 私有属性
    
    /// 持久监听 Task 引用（防止提前释放）
    private var transactionListenerTask: Task<Void, Never>?
    
    private init() {}
    
    // MARK: - 生命周期管理
    
    /// 启动 Transaction.updates 持久监听
    ///
    /// 必须在 App 启动时（`AppEnvironment.init()` 内）调用且仅调用一次。
    /// 重复调用会取消上一个监听 Task 并重新注册，以防重复监听。
    public func startListening() {
        // 防止重复注册
        transactionListenerTask?.cancel()
        
        transactionListenerTask = Task(priority: .background) { [weak self] in
            // StoreKit 2：异步流，持续接收来自 App Store 的交易更新
            for await verificationResult in Transaction.updates {
                guard let self else { break }
                await self.handle(transactionResult: verificationResult)
            }
        }
        
        Logger.shared.info("[StoreKitService] Transaction.updates 监听器已注册")
    }
    
    /// 停止监听（App 进入后台/退出时可选调用）
    public func stopListening() {
        transactionListenerTask?.cancel()
        transactionListenerTask = nil
    }
    
    // MARK: - 常量与交易分类

    private enum SyncConstants {
        /// AppStore.sync() 超时保护（5 秒，防模拟器无沙盒账号死锁）
        static let timeoutNanoseconds: UInt64 = 5_000_000_000
    }

    /// 交易判定结果（先校验商品归属，防止无关商品过期/退款误降级当前 Pro 权益）
    internal enum TransactionDecision: Equatable {
        case unknownProduct
        case revoked
        case expired
        case validPro
    }

    /// 判定单笔已验证交易的权益处理策略
    internal static func classifyTransaction(
        productId: String,
        revocationDate: Date?,
        expirationDate: Date?,
        now: Date = Date()
    ) -> TransactionDecision {
        guard AppConstants.Subscription.allProductIds.contains(productId) else {
            return .unknownProduct
        }
        if revocationDate != nil {
            return .revoked
        }
        if let expirationDate, expirationDate < now {
            return .expired
        }
        return .validPro
    }

    // MARK: - 恢复购买
    
    /// 触发 App Store 收据同步，恢复已购内购项目
    ///
    /// - 调用 `AppStore.sync()` 触发票据核验，已购但未激活的 Transaction 会通过
    ///   `Transaction.updates` 流重新推送，由 `handle(transactionResult:)` 完成本地激活。
    /// - 若用户未购买过任何项目，此调用会静默完成（不产生错误）。
    /// - 包含并发防重入与超时保护，避免双击重入状态踩踏及模拟器环境死锁。
    public func restorePurchases() async -> Bool {
        guard !isRestoring else { return false }
        isRestoring = true
        restoreMessage = nil

        do {
            // 触发 App Store 同步，附带超时保护防止模拟器环境死锁
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await StoreKit.AppStore.sync()
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: SyncConstants.timeoutNanoseconds)
                    throw StoreKitSyncTimeout()
                }
                try await group.next()
                group.cancelAll()
            }
            Logger.shared.info("[StoreKitService] 恢复购买同步成功")
            isRestoring = false
            restoreMessage = L10n.Auth.restoreSuccess
            return true
        } catch {
            Logger.shared.error("[StoreKitService] 恢复购买失败", error: error)
            isRestoring = false
            restoreMessage = L10n.Auth.restoreFailed
            return false
        }
    }
    
    // MARK: - 私有：交易处理
    
    /// 处理单条 Transaction 验证结果
    private func handle(transactionResult: VerificationResult<Transaction>) async {
        switch transactionResult {
        case .verified(let transaction):
            await processVerifiedTransaction(transaction)
        case .unverified(_, let error):
            // 未通过苹果签名校验，忽略并记录
            Logger.shared.warning("[StoreKitService] 收到未验证交易，错误: \(error.localizedDescription)")
        }
    }
    
    /// 处理已通过苹果校验的交易
    private func processVerifiedTransaction(_ transaction: Transaction) async {
        let productId = transaction.productID
        let decision = Self.classifyTransaction(
            productId: productId,
            revocationDate: transaction.revocationDate,
            expirationDate: transaction.expirationDate
        )

        switch decision {
        case .unknownProduct:
            // 未知 productId：绝不触发降级，仅记录 warning 并 finish 清理
            Logger.shared.warning("[StoreKitService] 收到未知 productId: \(productId)，未在 allProductIds 中注册")
            await transaction.finish()
        case .revoked:
            Logger.shared.warning("[StoreKitService] 交易已被吊销，降级用户权益 productId=\(productId)")
            downgradeToFree()
            await transaction.finish()
        case .expired:
            Logger.shared.info("[StoreKitService] 订阅已过期，降级用户权益 productId=\(productId)")
            downgradeToFree()
            await transaction.finish()
        case .validPro:
            Logger.shared.info("[StoreKitService] 有效内购交易，商品 ID: \(productId)，激活 Pro 权益")
            let receipt = transaction.jsonRepresentation.base64EncodedString()
            let success = await AuthService.shared.verifyApplePurchase(
                productId: productId,
                receiptData: receipt,
                orderNo: nil
            )
            if success {
                Logger.shared.info("[StoreKitService] 后端收据验证成功，Pro 权益已激活")
                await transaction.finish()
            } else {
                // 后端验证失败：不 finish 交易，并主动入队指数退避重试缩短到账等待
                await PaymentRetryQueue.shared.enqueue(
                    productId: productId,
                    receiptData: receipt,
                    transactionId: String(transaction.id),
                    orderNo: nil
                )
                Logger.shared.warning("[StoreKitService] 后端收据验证失败，已入队指数退避重试（交易未 finish）")
            }
        }
    }
    
    // MARK: - 权益降级
    
    /// 将当前用户降级为 Free 配额（订阅过期 / 退款时调用）
    ///
    /// - Important: 降级后必须持久化认证状态到 KeyStore，否则 App 重启自动登录
    ///   仍恢复 Pro 权益——造成"本地认为 Pro、服务端已降级"的权益残留不一致。
    func downgradeToFree() {
        guard let user = AuthSession.shared.currentUser,
              user.isPro else { return }
        
        let free = user.withPlan(
            planKey: PlanKey.free,
            maxVaults: User.DefaultQuotas.freeMaxVaults,
            maxPages: User.DefaultQuotas.freeMaxPages,
            maxPlugins: User.DefaultQuotas.freeMaxPlugins
        )
        AuthSession.shared.update(user: free)
        // 持久化降级后的认证状态，防止 App 重启自动登录时恢复 Pro 权益残留
        AuthService.shared.saveState()
        Logger.shared.info("[StoreKitService] 用户权益已降级为 Free 且状态已持久化")
    }
}

/// StoreKit 同步超时错误
private struct StoreKitSyncTimeout: Error {}

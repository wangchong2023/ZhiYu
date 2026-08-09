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
//    3. 监听到订阅过期时，自动将本地用户降级为 Lite 配额，防止权益残留。
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
    
    // MARK: - 恢复购买
    
    /// 触发 App Store 收据同步，恢复已购内购项目
    ///
    /// - 调用 `AppStore.sync()` 触发票据核验，已购但未激活的 Transaction 会通过
    ///   `Transaction.updates` 流重新推送，由 `handle(transactionResult:)` 完成本地激活。
    /// - 若用户未购买过任何项目，此调用会静默完成（不产生错误）。
    public func restorePurchases() async -> Bool {
        isRestoring = true
        restoreMessage = nil
        
        do {
            // 触发 App Store 同步
            // 使用 StoreKit. 前缀避免与项目自定义 AppStore 类命名冲突
            try await StoreKit.AppStore.sync()
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
        
        // 检查是否为已吊销（退款 / 家长控制撤销）的交易
        if let revocationDate = transaction.revocationDate {
            Logger.shared.warning("[StoreKitService] 交易已被吊销（\(revocationDate)），降级用户权益")
            downgradeToLite()
            await transaction.finish()
            return
        }
        
        // 检查订阅是否已过期
        if let expirationDate = transaction.expirationDate, expirationDate < Date() {
            Logger.shared.info("[StoreKitService] 订阅已过期（\(expirationDate)），降级用户权益")
            downgradeToLite()
            await transaction.finish()
            return
        }
        
        // 有效交易 - 检查商品 ID 并激活 Pro 权益
        if AppConstants.Subscription.allProductIds.contains(productId) {
            Logger.shared.info("[StoreKitService] 有效内购交易，商品 ID: \(productId)，激活 Pro 权益")
            
            // 向后端发送收据验证（同步权益）
            let receipt = transaction.jsonRepresentation.base64EncodedString()
            let success = await AuthService.shared.verifyApplePurchase(
                productId: productId,
                receiptData: receipt,
                orderNo: nil
            )
            
            if success {
                Logger.shared.info("[StoreKitService] 后端收据验证成功，Pro 权益已激活")
            } else {
                // 后端验证失败时，不立即降级（可能是网络波动）。
                // 保留本地 Pro 权益，待下次刷新时重试验证。
                Logger.shared.warning("[StoreKitService] 后端收据验证失败，保留本地权益待重试")
            }
        }
        
        // 标记交易已完成（防止重复处理）
        await transaction.finish()
    }
    
    // MARK: - 权益降级
    
    /// 将当前用户降级为 Lite 配额（订阅过期 / 退款时调用）
    private func downgradeToLite() {
        guard let user = AuthSession.shared.currentUser,
              user.planKey == "pro" else { return }
        
        let lite = User(
            id: user.id,
            name: user.name,
            email: user.email,
            phone: user.phone,
            avatarURL: user.avatarURL,
            planKey: "lite",
            maxVaults: user.maxVaults,
            maxPages: User.DefaultQuotas.liteMaxPages,
            maxPlugins: User.DefaultQuotas.liteMaxPlugins,
            gender: user.gender,
            birthday: user.birthday
        )
        AuthSession.shared.update(user: lite)
        Logger.shared.info("[StoreKitService] 用户权益已降级为 Lite")
    }
}

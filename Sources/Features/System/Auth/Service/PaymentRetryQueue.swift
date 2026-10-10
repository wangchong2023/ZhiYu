//
//  PaymentRetryQueue.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/10/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层 - Auth 子域
//  核心职责：支付凭证验证失败后的离线重试队列。
//    - 验证失败时不 finish StoreKit 交易（交易由 StoreKit 在下次启动重新推送），
//      本队列在此基础上提供指数退避的主动重试，缩短用户到账等待时间。
//    - 队列编码为 JSON 持久化到 UserDefaults，App 重启后自动恢复并继续重试。
//    - 重试走通用支付验证接口，携带当前 accessToken（requiresAuth: true）。
//

import Foundation
import UFPCore

/// 支付凭证验证失败重试队列
///
/// - 指数退避：30s / 60s / 120s / 300s / 900s，最多重试 5 次
/// - 幂等去重：以 `transactionId` 为队列 key，同一交易重复入队不会产生重复项
/// - 持久化：队列编码为 JSON 存入 UserDefaults，App 重启后调用 `start()` 恢复重试
/// - 线程安全：actor 隔离所有状态与调度
actor PaymentRetryQueue {

    /// 全局单例
    static let shared = PaymentRetryQueue()

    // MARK: - 常量

    /// 指数退避时间（秒）：第 n 次重试前的等待间隔
    private let backoffSeconds: [TimeInterval] = [30, 60, 120, 300, 900]
    /// 最大重试次数（达到后丢弃该交易）
    private let maxAttempts = 5
    /// 支付渠道标识（对齐后端 PaymentStrategyFactory 路由）
    private let channel = "APPLE"
    /// 持久化存储 key（UserDefaults）
    private let storageKey = AppConstants.Keys.Storage.paymentRetryQueue

    // MARK: - 状态

    /// 待重试的验证项（key: transactionId）
    private var pending: [String: PendingVerify] = [:]
    /// 当前正在运行的重试调度 Task
    private var scheduledTask: Task<Void, Never>?

    private init() {
        pending = Self.loadPersisted()
    }

    // MARK: - 对外接口

    /// 将一次失败的支付验证加入重试队列
    /// - Parameters:
    ///   - productId: App Store 商品 ID
    ///   - receiptData: StoreKit 返回的 Base64 编码收据
    ///   - transactionId: StoreKit 交易 ID（后端幂等去重）
    ///   - orderNo: 预建订单号（可选）
    func enqueue(productId: String, receiptData: String, transactionId: String, orderNo: String? = nil) {
        pending[transactionId] = PendingVerify(
            productId: productId,
            receiptData: receiptData,
            transactionId: transactionId,
            orderNo: orderNo,
            attemptCount: 0,
            lastAttemptAt: nil
        )
        persist()
        scheduleNextAttempt()
        Logger.shared.info("[PaymentRetryQueue] 支付验证失败已入队待重试 transactionId=\(transactionId)")
    }

    /// 启动重试调度（App 启动时调用，用于恢复上次未完成的重试）
    func start() {
        guard !pending.isEmpty else { return }
        scheduleNextAttempt()
    }

    // MARK: - 重试调度

    /// 为队列中最早的待重试项安排一次重试（幂等：已有调度在运行则跳过）
    private func scheduleNextAttempt() {
        guard scheduledTask == nil,
              let (transactionId, item) = oldestPending() else { return }

        let delay = backoffDelay(for: item.attemptCount)
        scheduledTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            await self?.performRetry(transactionId: transactionId)
            await self?.clearScheduledTask()
        }
    }

    /// 取出最早应重试（未达上限）的待重试项
    private func oldestPending() -> (String, PendingVerify)? {
        pending
            .filter { $0.value.attemptCount < maxAttempts }
            .min { ($0.value.lastAttemptAt ?? .distantPast) < ($1.value.lastAttemptAt ?? .distantPast) }
    }

    private func backoffDelay(for attemptCount: Int) -> TimeInterval {
        let index = min(attemptCount, backoffSeconds.count - 1)
        return backoffSeconds[index]
    }

    // MARK: - 重试执行

    /// 对指定交易执行一次后端验证；成功移除队列，失败则按退避调度下一次重试
    private func performRetry(transactionId: String) async {
        guard var item = pending[transactionId] else { return }

        item.attemptCount += 1
        item.lastAttemptAt = Date()
        pending[transactionId] = item
        persist()

        do {
            let _: VerifyResponse = try await NetworkClient.shared.request(
                path: APIPaths.subscriptionVerifyPath,
                method: SystemConstants.HTTPMethod.post,
                body: VerifyBody(
                    channel: channel,
                    productId: item.productId,
                    receiptData: item.receiptData,
                    transactionId: transactionId,
                    orderNo: item.orderNo
                ),
                requiresAuth: true
            )
            pending.removeValue(forKey: transactionId)
            persist()
            Logger.shared.info("[PaymentRetryQueue] 支付验证重试成功 transactionId=\(transactionId)")
        } catch {
            if item.attemptCount >= maxAttempts {
                pending.removeValue(forKey: transactionId)
                persist()
                Logger.shared.error("[PaymentRetryQueue] 支付验证重试达到上限，放弃 transactionId=\(transactionId)")
            } else {
                Logger.shared.warning("[PaymentRetryQueue] 支付验证重试失败（第 \(item.attemptCount)/\(maxAttempts) 次），稍后继续重试")
                scheduleNextAttempt()
            }
        }
    }

    /// 清空当前调度 Task，并在队列仍有待重试项时继续调度
    private func clearScheduledTask() {
        scheduledTask = nil
        if pending.contains(where: { $0.value.attemptCount < maxAttempts }) {
            scheduleNextAttempt()
        }
    }

    // MARK: - 持久化

    private func persist() {
        do {
            let data = try JSONEncoder().encode(Array(pending.values))
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            Logger.shared.error("[PaymentRetryQueue] 队列持久化失败", error: error)
        }
    }

    private static func loadPersisted() -> [String: PendingVerify] {
        guard let data = UserDefaults.standard.data(forKey: AppConstants.Keys.Storage.paymentRetryQueue) else {
            return [:]
        }
        do {
            let items = try JSONDecoder().decode([PendingVerify].self, from: data)
            return Dictionary(uniqueKeysWithValues: items.map { ($0.transactionId, $0) })
        } catch {
            Logger.shared.error("[PaymentRetryQueue] 队列恢复失败", error: error)
            return [:]
        }
    }

    // MARK: - 内部模型

    /// 一条待重试的验证项
    private struct PendingVerify: Codable, Sendable {
        let productId: String
        let receiptData: String
        let transactionId: String
        let orderNo: String?
        var attemptCount: Int
        var lastAttemptAt: Date?
    }

    /// 通用支付凭证验证请求体（对齐后端 PaymentVerifyRequest）
    private struct VerifyBody: Codable, Sendable {
        let channel: String
        let productId: String
        let receiptData: String
        let transactionId: String
        let orderNo: String?
    }

    /// 通用支付凭证验证响应体（仅需校验成功与否，字段宽松）
    private struct VerifyResponse: Codable, Sendable {
        let orderNo: String?
        let status: String?
        let planKey: String?
    }
}

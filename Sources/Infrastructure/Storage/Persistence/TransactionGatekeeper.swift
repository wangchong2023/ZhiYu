//
//  TransactionGatekeeper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/06.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：事务门禁 actor，封装活跃事务计数与排空逻辑，消除 DatabaseManager 事务排空 TOCTOU 竞态。
//

import Foundation

/// 排空等待者包装器，确保 continuation 只 resume 一次。
private final class DrainWaiter {
    private var continuation: CheckedContinuation<Void, Never>?
    init(continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }
    func resume() {
        if let cont = continuation {
            continuation = nil
            cont.resume()
        }
    }
}

/// 事务门禁 actor（Finding #18 修复）。
///
/// 用 actor 串行化事务计数操作，彻底消除 `DatabaseManager.switchDatabase` 排空检查的 TOCTOU 竞态：
/// - `acquire()` 在排空期间（`draining == true`）抛出 `DatabaseError.draining`，拒绝新事务进入
/// - `drain()` 设置 `draining = true` 并等待所有活跃事务完成（`activeCount == 0`）
/// - `release()` 递减活跃事务计数
///
/// 与原 `DatabaseManager.activeTransactionsCount` 的区别：
/// - 原实现：increment/decrement 在 @MainActor 串行化，但写事务在后台 actor 执行，
///   `switchDatabase` 排空循环 `while count > 0` + `Task.sleep` 让出主线程时 increment 可执行 → 竞态
/// - 新实现：所有计数操作在 `TransactionGatekeeper` actor 内串行化，`drain()` 期间 `acquire()` 抛错，
///   从语义层面保证排空期间无新事务进入
actor TransactionGatekeeper {

    /// 当前活跃事务计数（仅供测试观察，不依赖绝对值）。
    private(set) var activeCount: Int = 0

    /// 是否正在排空（Vault 热切换中）。
    private(set) var draining: Bool = false

    /// 排空完成时的延续回调队列，用于唤醒等待中的 `drain()`。
    private var drainWaiters: [DrainWaiter] = []

    /// 获取事务许可（事务开始前调用）。
    ///
    /// - Returns: 事务令牌，事务结束后需调用 `release()` 释放。
    /// - Throws: `DatabaseError.draining` 如果正在排空，拒绝新事务进入。
    func acquire() async throws {
        if draining {
            throw DatabaseError.draining
        }
        activeCount += 1
    }

    /// 释放事务许可（事务结束后调用）。
    func release() {
        if activeCount > 0 {
            activeCount -= 1
        }
        // 若计数归零且有 drain 等待者，唤醒它们
        if activeCount == 0 && !drainWaiters.isEmpty {
            let waiters = drainWaiters
            drainWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }
    }
    /// 排空所有活跃事务（Vault 热切换前调用）。
    ///
    /// - Parameter maxWaitTime: 最大等待时间，超时后强制返回（调用方决定是否强制关闭连接）。
    /// - Returns: 是否在超时前成功排空所有事务。
    func drain(maxWaitTime: Duration = .milliseconds(1500)) async -> Bool {
        draining = true
        let deadline = ContinuousClock().now.advanced(by: maxWaitTime)

        // 等待所有活跃事务完成
        while activeCount > 0 {
            let now = ContinuousClock().now
            if now >= deadline {
                // 超时，返回 false（调用方决定是否强制关闭）
                draining = false
                return false
            }
            // 等待 release() 唤醒或超时
            let remaining = deadline - now
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                // 用包装器确保 continuation 只 resume 一次
                let waiter = DrainWaiter(continuation: continuation)
                drainWaiters.append(waiter)
                // 超时唤醒
                Task { [weak self] in
                    try? await Task.sleep(for: remaining)
                    await self?.resumeWaiter(waiter)
                }
            }
        }

        draining = false
        return true
    }

    /// 重置状态（仅测试使用）。
    func reset() {
        activeCount = 0
        draining = false
        let waiters = drainWaiters
        drainWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    /// 唤醒指定等待者（超时 Task 调用，确保只 resume 一次）。
    private func resumeWaiter(_ waiter: DrainWaiter) {
        // 从队列中移除（如果还在）
        drainWaiters.removeAll { $0 === waiter }
        waiter.resume()
    }
}

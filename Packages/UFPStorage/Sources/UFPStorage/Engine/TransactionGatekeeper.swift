//
//  TransactionGatekeeper.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage] 通用存储引擎包
//  核心职责：事务门禁 actor，封装活跃事务计数与排空逻辑，消除事务排空 TOCTOU 竞态。
//           与业务完全无关，任何使用数据库连接池的上层模块均可复用。
//

import Foundation
import os

/// 排空等待者包装器，确保 continuation 只 resume 一次。
private final class DrainWaiter: @unchecked Sendable {
    private let continuation: OSAllocatedUnfairLock<CheckedContinuation<Void, Never>?>
    init(continuation: CheckedContinuation<Void, Never>) {
        self.continuation = OSAllocatedUnfairLock(initialState: continuation)
    }
    func resume() {
        let cont = continuation.withLock { lock -> CheckedContinuation<Void, Never>? in
            let value = lock
            lock = nil
            return value
        }
        cont?.resume()
    }
}

/// 事务门禁 actor。
///
/// 用 actor 串行化事务计数操作，彻底消除排空检查的 TOCTOU 竞态：
/// - `acquire()` 在排空期间（`draining == true`）抛出 `DatabaseError.draining`，拒绝新事务进入
/// - `drain()` 设置 `draining = true` 并等待所有活跃事务完成（`activeCount == 0`）
/// - `release()` 递减活跃事务计数
public actor TransactionGatekeeper {

    /// 当前活跃事务计数（仅供测试观察，不依赖绝对值）。
    public private(set) var activeCount: Int = 0

    /// 是否正在排空（Vault 热切换中）。
    public private(set) var draining: Bool = false

    /// 排空完成时的延续回调队列，用于唤醒等待中的 `drain()`。
    private var drainWaiters: [DrainWaiter] = []

    public init() {}

    /// 获取事务许可（事务开始前调用）。
    ///
    /// - Throws: `DatabaseError.draining` 如果正在排空，拒绝新事务进入。
    public func acquire() async throws {
        if draining {
            throw DatabaseError.draining
        }
        activeCount += 1
    }

    /// 释放事务许可（事务结束后调用）。
    public func release() {
        if activeCount > 0 {
            activeCount -= 1
        }
        // 若计数归零且有 drain 等待者，唤醒它们
        if activeCount == 0 && !drainWaiters.isEmpty {
            resumeAllDrainWaiters()
        }
    }

    /// 排空所有活跃事务（Vault 热切换前调用）。
    ///
    /// - Parameter maxWaitTime: 最大等待时间，超时后强制返回（调用方决定是否强制关闭连接）。
    /// - Returns: 是否在超时前成功排空所有事务。
    public func drain(maxWaitTime: Duration = .milliseconds(1500)) async -> Bool {
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
    public func reset() {
        activeCount = 0
        draining = false
        resumeAllDrainWaiters()
    }

    /// 设置排空状态（仅测试使用）。
    public func setDrainingForTesting(_ value: Bool) {
        draining = value
    }

    /// 唤醒所有 drain 等待者并清空队列（消除 release 与 reset 重复）。
    private func resumeAllDrainWaiters() {
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
//
//  IntentRateLimiter.swift
//  UFPCore
//
//  Created by Antigravity on 2026/06/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：限制特定写入操作的频率，采用 10Hz 滑动窗口限流算法保护底盘 (TC-DEE-06)。
//

import Foundation
import os

/// 限流参数常量
private enum RateLimitConstants {
    /// 滑动窗口内允许的最大请求次数（10Hz）
    static let maxRequests: Int = 10
    /// 滑动窗口时间跨度（秒）
    static let windowSeconds: TimeInterval = 1.0
}

/// 限制特定写入操作的频率，采用 10Hz 滑动窗口限流算法保护底盘 (TC-DEE-06)
public final class IntentRateLimiter: @unchecked Sendable, TestStateResettable {
    /// 单例实例
    public static let shared = IntentRateLimiter()

    // 使用 OSAllocatedUnfairLock 确保并发安全（Swift 5.9+，Sendable，无需手动 unlock）
    private let lock = OSAllocatedUnfairLock()
    private var requests: [Date] = []

    private init() {
        // 单例自注册到测试状态重置注册表
        TestStateResetRegistry.shared.register(self)
    }

    /// 尝试获取访问许可。如果 1 秒内请求次数超过 10 次，则熔断拒绝，否则允许并记录。
    /// - Returns: 是否允许本次操作
    public func request() -> Bool {
        lock.withLock {
            let now = Date()
            let windowStart = now.addingTimeInterval(-RateLimitConstants.windowSeconds)

            // 清理窗口外的历史请求记录
            requests = requests.filter { $0 > windowStart }

            if requests.count < RateLimitConstants.maxRequests {
                requests.append(now)
                return true
            } else {
                return false
            }
        }
    }

    /// 重置限流器（主要用于单元测试）
    public func reset() {
        lock.withLock { requests.removeAll() }
    }

    // MARK: - TestStateResettable

    /// 重置单例状态用于测试隔离
    public func resetStateForTesting() {
        reset()
    }
}
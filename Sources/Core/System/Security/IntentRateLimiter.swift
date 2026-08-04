//
//  IntentRateLimiter.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：限制特定写入操作的频率，采用 10Hz 滑动窗口限流算法保护底盘 (TC-DEE-06)。
//

import Foundation
import os

/// 限制特定写入操作的频率，采用 10Hz 滑动窗口限流算法保护底盘 (TC-DEE-06)
final class IntentRateLimiter: @unchecked Sendable {
    /// 单例实例
    static let shared = IntentRateLimiter()

    private let limit = 10
    private let windowSize: TimeInterval = 1.0

    // 使用 OSAllocatedUnfairLock 确保并发安全（Swift 5.9+，Sendable，无需手动 unlock）
    private let lock = OSAllocatedUnfairLock()
    private var requests: [Date] = []

    private init() {}

    /// 尝试获取访问许可。如果 1 秒内请求次数超过 10 次，则熔断拒绝，否则允许并记录。
    /// - Returns: 是否允许本次操作
    func request() -> Bool {
        lock.withLock {
            let now = Date()
            let windowStart = now.addingTimeInterval(-windowSize)

            // 清理窗口外的历史请求记录
            requests = requests.filter { $0 > windowStart }

            if requests.count < limit {
                requests.append(now)
                return true
            } else {
                return false
            }
        }
    }

    /// 重置限流器（主要用于单元测试）
    func reset() {
        lock.withLock { requests.removeAll() }
    }
}

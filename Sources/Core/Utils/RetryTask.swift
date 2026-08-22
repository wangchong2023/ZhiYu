//
//  RetryTask.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：提供通用的基于指数退避 (Exponential Backoff) 和抖动 (Jitter) 的异步任务重试机制，增强弱网容错性。
//

import Foundation

/// 异步重试任务工具
public enum RetryTask {

    /// 执行具备指数退避重试能力的异步任务
    /// - Parameters:
    ///   - maxRetries: 最大重试次数（不包含首次执行），默认 3 次
    ///   - initialDelay: 首次重试前的初始延迟，默认 1 秒
    ///   - multiplier: 每次重试延迟的指数乘数，默认 2.0
    ///   - maxDelay: 单次重试的最大延迟上限，默认 15 秒
    ///   - shouldRetry: 判断错误是否应该重试的谓词，默认 nil 表示所有错误都重试
    ///   - operation: 需要执行的可能抛出错误的异步闭包
    /// - Returns: 操作成功的返回值
    /// - Throws: 在耗尽重试次数后抛出最后一次的底层错误
    @discardableResult
    public static func execute<T>(
        maxRetries: Int = CoreConstants.RetryBackoff.defaultMaxRetries,
        initialDelay: TimeInterval = CoreConstants.RetryBackoff.defaultInitialDelay,
        multiplier: Double = CoreConstants.RetryBackoff.defaultMultiplier,
        maxDelay: TimeInterval = CoreConstants.RetryBackoff.defaultMaxDelay,
        shouldRetry: ((Error) -> Bool)? = nil,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var retries = 0
        var currentDelay = initialDelay

        while true {
            do {
                return try await operation()
            } catch {
                // 条件重试：谓词返回 false 时直接抛错
                if let shouldRetry, !shouldRetry(error) {
                    throw error
                }

                if retries >= maxRetries {
                    Logger.shared.error("[RetryTask] 重试耗尽 (\(maxRetries))", error: error)
                    throw error
                }

                retries += 1

                // 加入 Jitter (随机抖动) 防范惊群效应 (Thundering Herd Problem)
                let jitter = Double.random(in: 0.8...1.2)
                let actualDelay = min(currentDelay * jitter, maxDelay)

                Logger.shared.warning("[RetryTask] 第 \(retries)/\(maxRetries) 次重试: \(error.localizedDescription) 延迟 \(String(format: "%.2f", actualDelay))s ...")

                try await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
                currentDelay *= multiplier
            }
        }
    }

    /// 执行固定间隔轮询，直到条件满足或超时
    /// - Parameters:
    ///   - maxAttempts: 最大轮询次数
    ///   - interval: 每次轮询间隔（秒）
    ///   - condition: 轮询条件闭包，返回非 nil 时停止轮询并返回该值
    /// - Returns: 条件满足时返回的值
    /// - Throws: 轮询耗尽时抛出 `RetryError.pollingExhausted`
    public static func poll<T>(
        maxAttempts: Int,
        interval: TimeInterval,
        condition: @Sendable () async throws -> T?
    ) async throws -> T {
        for attempt in 0..<maxAttempts {
            if let result = try await condition() {
                return result
            }
            if attempt < maxAttempts - 1 {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
        throw RetryError.pollingExhausted(attempts: maxAttempts)
    }
}

/// 重试错误类型
public enum RetryError: Error, LocalizedError {
    /// 轮询耗尽
    case pollingExhausted(attempts: Int)

    public var errorDescription: String? {
        switch self {
        case .pollingExhausted(let attempts):
            return "Polling exhausted after \(attempts) attempts"
        }
    }
}

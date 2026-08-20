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
    ///   - operation: 需要执行的可能抛出错误的异步闭包
    /// - Returns: 操作成功的返回值
    /// - Throws: 在耗尽重试次数后抛出最后一次的底层错误
    @discardableResult
    /// 执行带指数退避和抖动的异步重试任务
    public static func execute<T>(
        maxRetries: Int = CoreConstants.RetryBackoff.defaultMaxRetries,
        initialDelay: TimeInterval = CoreConstants.RetryBackoff.defaultInitialDelay,
        multiplier: Double = CoreConstants.RetryBackoff.defaultMultiplier,
        maxDelay: TimeInterval = CoreConstants.RetryBackoff.defaultMaxDelay,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var retries = 0
        var currentDelay = initialDelay
        
        while true {
            do {
                // 尝试执行核心业务逻辑
                return try await operation()
            } catch {
                if retries >= maxRetries {
                    // 重试次数耗尽，直接抛出异常
                    Logger.shared.error("[RetryTask]  (\(maxRetries))", error: error)
                    throw error
                }
                
                retries += 1
                
                // 加入 Jitter (随机抖动) 防范惊群效应 (Thundering Herd Problem)
                // 抖动范围：当前延迟的 80% 到 120% 之间
                let jitter = Double.random(in: 0.8...1.2)
                let actualDelay = min(currentDelay * jitter, maxDelay)
                
                Logger.shared.warning("[RetryTask] : \(error.localizedDescription) \(retries)/\(maxRetries)  \(String(format: "%.2f", actualDelay)) ...")
                
                // 挂起协程等待重试
                try await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
                
                // 指数退避更新下一次的基准延迟
                currentDelay *= multiplier
            }
        }
    }
}

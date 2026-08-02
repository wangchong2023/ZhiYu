//
//  DatabaseWriterProvider.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：提取重复的 dbWriter 动态计算属性至协议扩展，消除 4 个 Repository 中的 11 行重复样板。
//

import Foundation
import UFPStorage

/// 提供动态 `dbWriter` 计算属性的协议。
///
/// 默认实现从 `DatabaseManager.shared.dbWriter` 获取当前活跃的数据库写入器，
/// 支持多 Vault 热插拔切换。若尚未初始化（如测试冷启动），则降级创建内存数据库队列。
protocol DatabaseWriterProvider: AnyObject {
    var dbWriter: any DatabaseWriter { get async }
}

extension DatabaseWriterProvider {
    var dbWriter: any DatabaseWriter {
        get async {
            // 直接 await @MainActor 属性，避免 MainActor.run 在 XCTest 并行 worker 中死锁。
            // MainActor.run 通过 withCheckedContinuation 显式调度任务，与 XCTest 自定义 run loop
            // 冲突；而直接 await 使用 Swift 结构化并发的 actor hop，与 XCTest 协作更好。
            if let writer = await DatabaseManager.shared.dbWriter {
                return writer
            }
            // DatabaseQueue() 创建在调用方 actor 上执行，不阻塞主线程
            do { return try DatabaseQueue() } catch {
                fatalError("无法创建内存数据库(DatabaseWriterProvider): \(error)")
            }
        }
    }
}

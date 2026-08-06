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
/// 支持多 Vault 热插拔切换。若尚未初始化（如启动早期、Vault 热切换瞬态），
/// 抛出 `DatabaseError.notReady`，由调用方决定降级策略（排队等待、提示用户重试）。
///
/// Finding #17 修复：原实现静默降级创建空内存 DatabaseQueue，数据写入临时库后丢失。
/// 改为抛出明确错误，避免静默数据丢失。
protocol DatabaseWriterProvider: AnyObject {
    var dbWriter: any DatabaseWriter { get async throws }
}

extension DatabaseWriterProvider {
    var dbWriter: any DatabaseWriter {
        get async throws {
            // 直接 await @MainActor 属性，避免 MainActor.run 在 XCTest 并行 worker 中死锁。
            if let writer = await DatabaseManager.shared.dbWriter {
                return writer
            }
            // Finding #17：dbWriter 为 nil 时抛错，不再静默降级创建空内存库
            throw DatabaseError.notReady
        }
    }
}

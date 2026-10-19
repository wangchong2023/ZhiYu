//
//  DatabaseBootstrapStrategy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：数据库引导配置策略协议，解耦生产文件持久化数据库与测试内存数据库的初始化。
//

import Foundation
import UFPCore
import UFPStorage

/// 数据库引导配置策略协议
@MainActor
public protocol DatabaseBootstrapStrategy: Sendable {
    func setup(at defaultURL: URL) throws
}

/// 默认持久化存储策略（生产默认）
@MainActor
public struct PersistentDatabaseBootstrapStrategy: DatabaseBootstrapStrategy {
    public init() {}
    public func setup(at defaultURL: URL) throws {
        try DatabaseManager.shared.setup(at: defaultURL)
    }
}

/// 内存临时存储策略（供测试套件或临时沙箱隔离使用）
@MainActor
public struct EphemeralDatabaseBootstrapStrategy: DatabaseBootstrapStrategy {
    public init() {}
    public func setup(at defaultURL: URL) throws {
        let memoryQueue = try DatabaseQueue()
        try DatabaseManager.shared.setup(with: memoryQueue)
    }
}

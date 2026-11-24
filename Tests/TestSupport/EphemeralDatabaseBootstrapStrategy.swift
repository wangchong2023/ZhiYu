//
//  EphemeralDatabaseBootstrapStrategy.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试基础设施
//  核心职责：为测试应用提供内存数据库，避免读取生产数据。
//
import Foundation
import UFPStorage

/// 内存临时存储策略（供测试套件或临时沙箱隔离使用）
@MainActor
public struct EphemeralDatabaseBootstrapStrategy: DatabaseBootstrapStrategy {
    public init() {}
    public func setup(at defaultURL: URL) throws {
        let memoryQueue = try DatabaseQueue()
        try DatabaseManager.shared.setup(with: memoryQueue)
    }
}

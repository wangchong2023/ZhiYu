//
//  GenericSQLiteEngine.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage] 通用存储引擎包
//  核心职责：基于 GRDB 的泛型 CRUD / 事务 / 查询骨架，零业务模型依赖。
//

import Foundation
import UFPCore

/// 通用 GRDB 引擎骨架。
///
/// 封装基于 `DatabaseWriter` 的泛型写入、读取、事务与 Codable 泛型 CRUD 操作。
/// 与业务完全无关——不引用任何业务模型、协议或常量，任何 App 均可复用。
/// 泛型参数约束为 `Sendable`，以保证跨 actor 传输安全。
public final class GenericSQLiteEngine {

    /// 底层数据库连接写入器。
    private let writer: any DatabaseWriter

    /// 基于指定数据库连接构建引擎。
    /// - Parameter writer: 数据库连接写入器（DatabaseQueue / DatabasePool）。
    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    // MARK: - 通用读写

    /// 在事务中执行写入闭包。
    /// - Parameter block: 写入闭包，接收 `Database` 连接。
    /// - Returns: 闭包返回值。
    /// - Throws: 写入或事务异常。
    public func write<T>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        try await writer.write(block)
    }

    /// 执行只读查询闭包。
    /// - Parameter block: 只读闭包，接收 `Database` 连接。
    /// - Returns: 闭包返回值。
    /// - Throws: 读取异常。
    public func read<T>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        try await writer.read(block)
    }

    // MARK: - 泛型 Codable CRUD

    /// 批量插入 Codable 模型（`MutablePersistableRecord` 编码）。
    /// - Parameter models: 待插入的模型数组。
    /// - Throws: 插入或事务异常。
    public func insertAll<Model: TableRecord & MutablePersistableRecord & Encodable & Sendable>(_ models: [Model]) async throws {
        try await writer.write { db in
            for var model in models {
                try model.insert(db)
            }
        }
    }

    /// 全量拉取指定类型的 Codable 模型记录。
    /// - Parameter type: 模型类型（须遵循 `TableRecord & FetchableRecord & Sendable`）。
    /// - Returns: 记录数组。
    /// - Throws: 查询异常。
    public func fetchAll<Model: TableRecord & FetchableRecord & Sendable>(_ type: Model.Type) async throws -> [Model] {
        try await writer.read { db in
            try Model.fetchAll(db)
        }
    }

    /// 清空指定表全部记录。
    /// - Parameter type: 模型类型（须遵循 `TableRecord & Sendable`）。
    /// - Throws: 删除或事务异常。
    public func deleteAll<Model: TableRecord & Sendable>(_ type: Model.Type) async throws {
        try await writer.write { db in
            _ = try Model.deleteAll(db)
        }
    }

    /// 统计指定表的记录条数。
    /// - Parameter type: 模型类型（须遵循 `TableRecord & Sendable`）。
    /// - Returns: 记录条数。
    /// - Throws: 查询异常。
    public func count<Model: TableRecord & Sendable>(_ type: Model.Type) async throws -> Int {
        try await writer.read { db in
            try Model.fetchCount(db)
        }
    }
}
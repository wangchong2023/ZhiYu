//
//  GenericSchemaMigrator.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage] 通用存储引擎包
//  核心职责：通用 GRDB 迁移执行器封装（注册/执行/幂等判断）。
//           仅提供迁移机制，严禁内嵌任何业务表名或业务 schema。
//

import Foundation
import UFPCore

/// 通用 GRDB 迁移执行器。
///
/// 封装 GRDB `DatabaseMigrator` 的注册与执行机制，供上层（App）注入业务 schema 迁移闭包。
/// 本类型与业务完全无关——不含任何业务表名、字段或业务常量。
public final class GenericSchemaMigrator {

    /// 底层 GRDB 迁移器（惰性构建，逐步注册）。
    private var migrator: DatabaseMigrator = DatabaseMigrator()

    /// 创建一个通用迁移执行器。
    public init() {}

    /// 注册一条增量迁移。
    /// - Parameters:
    ///   - identifier: 迁移唯一标识（应保持稳定，不得复用或改名）。
    ///   - migrate: 迁移闭包，在目标数据库连接上执行 schema 变更。
    public func registerMigration(_ identifier: String, migrate: @escaping (Database) throws -> Void) {
        migrator.registerMigration(identifier, migrate: migrate)
    }

    /// 对指定数据库连接执行所有已注册且尚未执行的迁移。
    /// - Parameter writer: 目标数据库连接写入器。
    /// - Throws: 迁移执行异常。
    public func migrate(_ writer: any DatabaseWriter) throws {
        try migrator.migrate(writer)
    }

    /// 判断指定数据库连接是否已完成全部已注册迁移。
    /// - Parameter writer: 目标数据库连接写入器。
    /// - Returns: 是否已完成全部迁移。
    /// - Throws: 数据库读取异常。
    public func hasCompletedMigrations(_ writer: any DatabaseWriter) throws -> Bool {
        try writer.read { db in
            try migrator.hasCompletedMigrations(db)
        }
    }
}
//
//  PluginRecord+GRDB.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：持久化引擎：GRDB/SQLite 仓库、同步、加密、数据库管理。
//

import UFPStorage
import Foundation

// MARK: - GRDB 协议遵循

extension PluginRecord: FetchableRecord, MutablePersistableRecord {
    public static var databaseTableName: String {
        AppConstants.Storage.Tables.pluginRecords
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
    }

    public mutating func willUpdate(_ columns: Set<String>) {
        updatedAt = Date()
    }
}

// MARK: - Database Schema (Type-Safe ColumnExpression)

extension PluginRecord {
    public enum Columns: String, ColumnExpression {
        case id
        case name
        case version
        case author
        case source
        case status
        case permissionsJSON = "permissions_json"
        case loadDuration = "load_duration"
        case unloadDuration = "unload_duration"
        case totalExecutionTime = "total_execution_time"
        case callCount = "call_count"
        case installedAt = "installed_at"
        case updatedAt = "updated_at"
        case manifestJSON = "manifest_json"
    }
}

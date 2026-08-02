//
//  KnowledgePage+GRDB.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：持久化引擎：GRDB/SQLite 仓库、同步、加密、数据库管理。
//
import UFPStorage
import Foundation

// MARK: - GRDB 协议遵循
extension KnowledgePage: FetchableRecord, PersistableRecord {}

// MARK: - Database Schema (Type-Safe Industrial Standard)
extension KnowledgePage {
    /// 定义数据库列名，遵循 ColumnExpression 协议。
    /// 业界方案：利用枚举 rawValue 映射列名，实现编译期静态检查。
    enum Columns: String, ColumnExpression {
        case id
        case title
        case pageType = "page_type"
        case content
        case aliases
        case tags
        case status
        case confidence
        case sources
        case relatedPageIDs = "related_page_ids"
        case isPinned = "is_pinned"
        case contentHash = "content_hash"
        case customIcon = "custom_icon"
        case sourceURL = "source_url"
        case rawTextSnippet = "raw_snippet"
        case fileSize = "file_size"
        case sourceType = "source_type"
        case lamportTimestamp = "lamport_timestamp"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 限定数组持久化的泛型范围以避免 Swift 编译器类型推导崩溃
public protocol GRDBJSONCodable: Codable {}
extension String: GRDBJSONCodable {}
extension UUID: GRDBJSONCodable {}
extension KnowledgeSource: GRDBJSONCodable {}

// MARK: - GRDB 数组持久化支持
// 工业级做法：通过 JSON 序列化存储数组类型。
extension Array: @retroactive DatabaseValueConvertible where Element: GRDBJSONCodable {
    public var databaseValue: DatabaseValue {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return .null
        }
        return string.databaseValue
    }

    /// fromDatabaseValue
    /// - Parameter dbValue: dbValue
    /// - Returns: 列表
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> [Element]? {
        guard let string = String.fromDatabaseValue(dbValue),
              let data = string.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}

// 必须显式声明父协议遵循
extension Array: @retroactive SQLExpressible where Element: GRDBJSONCodable { }
extension Array: @retroactive StatementBinding where Element: GRDBJSONCodable { }

extension Array: @retroactive StatementColumnConvertible where Element: GRDBJSONCodable {
    public init?(sqliteStatement: SQLiteStatement, index: Int32) {
        let dbValue = DatabaseValue(sqliteStatement: sqliteStatement, index: CInt(index))
        if let array = Self.fromDatabaseValue(dbValue) {
            self = array
        } else {
            return nil
        }
    }
}

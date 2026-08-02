//
//  SQLiteVaultRepository.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：持久化引擎：GRDB/SQLite 仓库、同步、加密、数据库管理。
//
import Foundation
import UFPStorage

/// [Infra] 用于映射 `global_vaults` 表的 GRDB 类型安全实体
struct VaultRecord: Codable, FetchableRecord, MutablePersistableRecord, TableRecord {
    // 映射的数据库表名
    static let databaseTableName = AppConstants.Storage.Tables.globalVaults

    var id: String
    var name: String
    var path: String
    var icon: String?
    var pageCount: Int
    var createdAt: Date
    var updatedAt: Date
    var lastAccessedAt: Date

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case name
        case path
        case icon
        case pageCount = "page_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastAccessedAt = "last_accessed_at"
    }
}

/// [Infra] SQLite 笔记本仓储实现类
final class SQLiteVaultRepository: VaultRepository, @unchecked Sendable {
    
    private let dbWriter: any DatabaseWriter
    
    /// 初始化笔记本仓储
    /// - Parameter dbWriter: GRDB 数据库连接池写入接口
    init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }
    
    // MARK: - VaultRepository 协议接口实现
    
    /// 获取所有笔记本元数据列表 (按最后访问时间降序排列) - 纯安全 ORM
    func fetchAllVaults() async throws -> [Vault] {
        try await dbWriter.read { db in
            let records = try VaultRecord
                .order(VaultRecord.CodingKeys.lastAccessedAt.desc)
                .fetchAll(db)
            
            return records.map { record in
                Vault(
                    id: UUID(uuidString: record.id) ?? UUID(),
                    name: record.name,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt,
                    pageCount: record.pageCount,
                    themePayload: nil,
                    icon: record.icon,
                    description: record.path
                )
            }
        }
    }
    
    /// 保存或更新单个笔记本元数据 - 纯安全 ORM
    func saveVault(_ vault: Vault) async throws {
        try await dbWriter.write { db in
            var record = VaultRecord(
                id: vault.id.uuidString,
                name: vault.name,
                path: vault.description ?? "",
                icon: vault.icon,
                pageCount: vault.pageCount,
                createdAt: vault.createdAt,
                updatedAt: vault.updatedAt,
                lastAccessedAt: Date()
            )
            try record.save(db)
        }
    }
    
    /// 更新指定笔记本的最后访问时间戳为当前时间 - 纯安全 ORM
    func updateLastAccessed(id: UUID) async throws {
        try await dbWriter.write { db in
            if var record = try VaultRecord.fetchOne(db, key: id.uuidString) {
                record.lastAccessedAt = Date()
                try record.save(db)
            }
        }
    }
    
    /// 从元数据表中物理删除指定笔记本 - 纯安全 ORM
    func deleteVault(id: UUID) async throws {
        try await dbWriter.write { db in
            _ = try VaultRecord.deleteOne(db, key: id.uuidString)
        }
    }

    /// 写入全局配置项 - 纯安全 ORM
    func saveSetting(key: String, value: String) async throws {
        try await dbWriter.write { db in
            var record = GlobalSettingRecord(key: key, value: value)
            try record.save(db)
        }
    }
}

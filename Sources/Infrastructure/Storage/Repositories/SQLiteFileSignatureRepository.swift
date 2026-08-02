//
//  SQLiteFileSignatureRepository.swift
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

/// [Infra] 用于映射 `file_signatures` 表的 GRDB 类型安全实体
struct FileSignatureRecord: Codable, FetchableRecord, MutablePersistableRecord, TableRecord {
    // 映射的数据库表名
    static let databaseTableName = AppConstants.Storage.Tables.fileSignatures
    
    var filePath: String
    var signature: String
    var salt: String
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case signature
        case salt
        case updatedAt = "updated_at"
    }
}

// MARK: - Database Columns
extension FileSignatureRecord {
    enum Columns {
        static let filePath = Column("file_path")
        static let signature = Column("signature")
        static let salt = Column("salt")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}

/// [Infra] SQLite 文件防篡改指纹仓储实现类
final class SQLiteFileSignatureRepository: FileSignatureRepository, @unchecked Sendable {
    
    private let dbWriter: any DatabaseWriter
    
    /// 初始化指纹仓储
    /// - Parameter dbWriter: GRDB 数据库连接池写入接口
    init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }
    
    // MARK: - FileSignatureRepository 协议接口实现
    
    /// 获取当前存储的指纹总数量 (用于冷启动盐值选择与向下兼容) - 纯安全 ORM
    func fetchSignatureCount() async throws -> Int {
        try await dbWriter.read { db in
            try FileSignatureRecord.fetchCount(db)
        }
    }
    
    /// 保存或更新指定物理文件的 HMAC 签名指纹 - 纯安全 ORM
    func saveSignature(_ signature: String, forFilePath filePath: String, salt: String) async throws {
        try await dbWriter.write { db in
            var record = FileSignatureRecord(
                filePath: filePath,
                signature: signature,
                salt: salt,
                updatedAt: Date()
            )
            try record.save(db)
        }
    }
    
    /// 获取指定物理文件的已保存 HMAC 签名指纹 - 纯安全 ORM
    func fetchSignature(forFilePath filePath: String) async throws -> String? {
        try await dbWriter.read { db in
            let record = try FileSignatureRecord.fetchOne(db, key: filePath)
            return record?.signature
        }
    }
}

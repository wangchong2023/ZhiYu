//
//  KnowledgePageFTS+GRDB.swift
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
extension KnowledgePageFTS: FetchableRecord, PersistableRecord {
    public static let databaseTableName = AppConstants.Storage.Tables.pagesFTS
}

// MARK: - Database Schema
extension KnowledgePageFTS {
    /// 物理字段映射，提供编译期静态检查
    public enum Columns {
        public static let id = Column("id")
        public static let title = Column("title")
        public static let content = Column("content")
        public static let tags = Column("tags")
        public static let aliases = Column("aliases")
    }
}

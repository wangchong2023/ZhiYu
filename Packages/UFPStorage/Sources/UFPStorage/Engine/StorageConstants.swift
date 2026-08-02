//
//  StorageConstants.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage]
//  核心职责：通用存储与 SQLite/GRDB 物理数据库常量配置。
//

import Foundation
import UFPCore

public enum StorageConstants {
    /// 默认数据库文件名
    public static let databaseFileName = "ZhiYu.sqlite"

    /// 表名与视图名
    public struct Tables {
        public static let pages = "knowledge_pages"
        public static let pageLinks = "page_links"
        public static let tags = "tags"
        public static let ftsPages = "knowledge_pages_fts"
        public static let vectorIndex = "vector_index"
    }

    /// 限制与默认尺寸
    public struct Limits {
        public static let maxBatchInsertSize: Int = 500
        public static let defaultPageSize: Int = 20
    }
}

//
//  PluginRecordFTS+GRDB.swift
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

extension PluginRecordFTS: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String {
        AppConstants.Storage.Tables.pluginRecordsFTS
    }

    public static var databaseSelection: [any SQLSelectable] {
        [AllColumns()]
    }
}

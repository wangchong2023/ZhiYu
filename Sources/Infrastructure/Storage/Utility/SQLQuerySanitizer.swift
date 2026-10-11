//
//  SQLQuerySanitizer.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层 / 存储
//  核心职责：SQL 查询清洗兼容层——已下沉至 UFPStorage `SQLQuerySanitizer`，此处仅重导出保持引用稳定。
//

import UFPStorage

/// SQL 查询清洗工具兼容层（指向 UFPStorage 通用实现）。
typealias SQLQuerySanitizer = UFPStorage.SQLQuerySanitizer

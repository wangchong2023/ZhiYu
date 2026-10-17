//
//  SQLQuerySanitizer.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage] 通用存储引擎包
//  核心职责：SQL 与 FTS5 查询关键字过滤与 LIKE 通配符转义，防止全表扫描穿透与语法错误。
//           与业务完全无关。
//

import Foundation

/// 通用存储引擎：SQL 查询清洗工具。
public enum SQLQuerySanitizer {

    /// 转义 SQL LIKE 查询中的通配符（`%`, `_`, `\`），防止用户输入特殊字符引发意外全表扫描或误匹配
    /// - Parameter query: 原始搜索词
    /// - Returns: 转义后的安全模糊匹配字面量（两端包裹 `%`）
    public static func makeLikePattern(_ query: String) -> String {
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return "%\(escaped)%"
    }

    /// 校验搜索词是否有效（非空且去除空白后具有最小有效检索长度）
    /// - Parameter query: 原始搜索词
    /// - Returns: 是否为有效查询
    public static func isValidQuery(_ query: String) -> Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
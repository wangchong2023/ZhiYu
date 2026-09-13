//
//  RepositoryBootstrap.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：提取重复的 dbWriter 静态存储声明至协议，消除 3 个 SQLite Repository 中的初始化样板重复。
//

import Foundation
import UFPStorage

/// Repository 初始化样板协议，消除 SQLiteXxxRepository 重复的 dbWriter 存储声明。
///
/// 与 `DatabaseWriterProvider` 不同，本协议用于构造时注入的静态 `dbWriter`（如 `SQLiteFileSignatureRepository`、
/// `SQLitePluginRepository`、`SQLiteVaultRepository`），而非运行时动态从 `DatabaseManager` 解析。
protocol RepositoryBootstrap: AnyObject {
    var dbWriter: any DatabaseWriter { get }
}

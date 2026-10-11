//
//  StorageConstants.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage] 通用存储引擎包
//  核心职责：纯通用 SQLite/GRDB 基础设施配置常量。
//           严禁包含任何业务表名或业务域常量。
//

import Foundation

/// 通用 SQLite 引擎配置常量（与业务完全无关）
public enum StorageConstants {

    // MARK: - 引擎行为
    /// WAL 模式检查点触发阈值（写入页数）
    public static let walCheckpointThreshold: Int32 = 1000
    /// 连接超时（秒）
    public static let connectionTimeout: TimeInterval = 30
    /// 默认 SQLite 页大小（字节）
    public static let defaultPageSize: Int32 = 4096

    // MARK: - 引擎配置 (Engine Configuration)
    /// WAL 读写分离连接池的最大并发读取线程数
    public static let maximumReaderCount: Int = 5
    /// SQLite 同步模式：NORMAL（WAL 黄金同步级别）
    public static let synchronousModeNormal: String = "NORMAL"
    /// 临时表/中间索引存储位置：MEMORY
    public static let tempStoreMemory: String = "MEMORY"
    /// 连接级大页面缓存（负数以 KB 为单位，约 10MB）
    public static let cacheSizeBytes: Int32 = -10000
    /// 内存映射 I/O 大小（字节，约 256MB）
    public static let mmapSizeBytes: Int64 = 268435456
    /// 锁等待超时（毫秒），打消多线程冷读写瞬时 SQLITE_BUSY
    public static let busyTimeoutMilliseconds: Int32 = 5000

    // MARK: - 限制
    /// 默认批量写入上限（可被上层覆盖）
    public static let defaultBatchInsertLimit: Int = 500
    /// 默认分页大小
    public static let defaultPageLimit: Int = 20
}

//
//  DatabaseError.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage] 通用存储引擎包
//  核心职责：物理隔离层强类型异常，与业务完全无关。
//

import Foundation

/// 通用存储引擎强类型异常。
public enum DatabaseError: Error {
    /// 数据库未就绪（dbWriter 为 nil，如启动早期、Vault 热切换瞬态、reset 后）。
    case notReady
    /// 数据库正在排空（Vault 热切换中，拒绝新事务）。
    case draining
}
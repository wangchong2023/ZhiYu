//
//  LocalizationTableEntry.swift
//  UFPCore
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：本地化表条目协议声明（与业务无关）。
//           tr/trf 默认实现依赖具体 App 层的翻译中枢，由 App 层扩展补充，
//           避免 UFPCore 反向依赖上层。
//

import Foundation

/// 为本地化命名空间中的枚举/结构体提供 `tr`/`trf` 默认实现基础的协议。
///
/// 仅声明表名，翻译执行（`tr`/`trf`）的默认实现由上层（如 App 层）以扩展方式补充，
/// 使 UFPCore 保持零本地化资源与零上层依赖。
public protocol L10nTableEntry {
    static var tableName: String { get }
}
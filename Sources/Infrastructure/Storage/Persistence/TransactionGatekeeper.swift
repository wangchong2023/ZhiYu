//
//  TransactionGatekeeper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/06.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：事务门禁兼容层——已下沉至 UFPStorage `TransactionGatekeeper`，此处仅重导出保持引用稳定。
//

import UFPStorage

/// 事务门禁兼容层（指向 UFPStorage 通用 actor）。
typealias TransactionGatekeeper = UFPStorage.TransactionGatekeeper

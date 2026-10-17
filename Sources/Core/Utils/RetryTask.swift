//
//  RetryTask.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：兼容层。RetryTask 已下沉至 UFPCore 通用底座包，此处保留 typealias 以维持 App 层既有调用点（LLMClient / SQLiteStore）无需改动。
//

import Foundation
import UFPCore

/// 异步重试任务工具（兼容层，实际实现见 `UFPCore.RetryTask`）
public typealias RetryTask = UFPCore.RetryTask

/// 重试错误类型（兼容层，实际实现见 `UFPCore.RetryError`）
public typealias RetryError = UFPCore.RetryError

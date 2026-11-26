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

/// 兼容性别名：指向已下沉至 UFPCore 的安全与文档格式基础组件
public typealias AESGCMCryptoHelper = UFPCore.AESGCMCryptoHelper
public typealias SecurityError = UFPCore.SecurityError
public typealias DocumentFormat = UFPCore.DocumentFormat
public typealias MultilingualTextSanitizer = UFPCore.MultilingualTextSanitizer
public typealias HomophonePinyinSanitizer = UFPCore.HomophonePinyinSanitizer
public typealias APIPaths = UFPCore.APIPaths
public typealias BackgroundTaskProtocol = UFPCore.BackgroundTaskProtocol
public typealias StubBackgroundTaskProvider = UFPCore.StubBackgroundTaskProvider
public typealias ReminderServiceProtocol = UFPCore.ReminderServiceProtocol
public typealias UnsupportedReminderService = UFPCore.UnsupportedReminderService
public typealias WatchSyncProtocol = UFPCore.WatchSyncProtocol
public typealias StubWatchSyncService = UFPCore.StubWatchSyncService
public typealias AhoMatch = UFPCore.AhoMatch
public typealias AhoCorasickEngine = UFPCore.AhoCorasickEngine
public typealias ApiResponse<T: Codable & Sendable> = UFPCore.ApiResponse<T>
public typealias EmptyData = UFPCore.EmptyData
public typealias NetworkError = UFPCore.NetworkError
public typealias IntentRateLimiter = UFPCore.IntentRateLimiter
public typealias JSONExtractor = UFPCore.JSONExtractor
public typealias LLMLatencyCalculator = UFPCore.LLMLatencyCalculator
public typealias RegexReplacementHelper = UFPCore.RegexReplacementHelper
public typealias CJKSpacingFormatter = UFPCore.CJKSpacingFormatter
public typealias PanguFormatter = UFPCore.CJKSpacingFormatter

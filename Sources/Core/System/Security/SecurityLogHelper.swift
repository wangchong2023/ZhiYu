//
//  SecurityLogHelper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：提供 Security 模块统一的错误日志记录辅助方法，消除 SecurityManager / DynamicComplianceManager+Patch 中重复的 Logger.addLog 错误日志代码块。
//
import Foundation

/// Security 模块错误日志辅助
/// 抽取 SecurityManager 与 DynamicComplianceManager+Patch 中重复的
/// `Logger.shared.addLog(action: .error, target: ..., details: ..., module: ...)` 模式。
enum SecurityLogHelper {

    /// 记录 Security 模块错误日志
    /// - Parameters:
    ///   - target: 日志目标（引用 `CoreConstants.SecurityLogTarget`）
    ///   - details: 错误详情
    static func logError(target: String, details: String) {
        Logger.shared.addLog(
            action: .error,
            target: target,
            details: details,
            module: CoreConstants.Security.logModule
        )
    }
}

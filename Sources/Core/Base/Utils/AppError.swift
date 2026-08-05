//
//  AppError.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：统一的应用级错误工厂，消除重复的 NSError(domain:code:userInfo:) 样板代码。

import Foundation
import UFPCore

/// 统一错误工厂：将分散在项目中的 NSError(domain:code:userInfo:) 收敛至此
public enum AppError {
    /// 创建带本地化描述的 NSError
    /// - Parameters:
    ///   - domain: 错误域（如模块名）
    ///   - code: 错误码，默认 -1
    ///   - description: 用户可读的错误描述
    /// - Returns: NSError 实例
    public static func make(domain: String, code: Int = CoreConstants.ErrorCode.default, description: String) -> NSError {
        NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: description])
    }
}

// MARK: - 常见模块错误便捷方法

public extension AppError {
    /// 知识洞察模块错误
    static func insight(_ description: String, code: Int = CoreConstants.ErrorCode.default) -> NSError {
        make(domain: CoreConstants.ErrorDomain.insight, code: code, description: description)
    }

    /// 知识摄入/存储模块错误
    static func ingest(_ description: String, code: Int = CoreConstants.ErrorCode.default) -> NSError {
        make(domain: CoreConstants.ErrorDomain.ingestStore, code: code, description: description)
    }

    /// 导出功能不支持错误（默认 501 Not Implemented）
    static func exportNotSupported(_ description: String = CoreConstants.Export.unsupportedMessage) -> NSError {
        make(domain: CoreConstants.ErrorDomain.export, code: SystemConstants.HTTPStatusCode.notImplemented, description: description)
    }

    /// 认证模块错误
    static func auth(domain: String, code: Int = CoreConstants.ErrorCode.default, description: String) -> NSError {
        make(domain: domain, code: code, description: description)
    }

    /// AI 合成模块错误
    static func synthesis(_ description: String, code: Int = CoreConstants.ErrorCode.default) -> NSError {
        make(domain: CoreConstants.ErrorDomain.synthesisStore, code: code, description: description)
    }

    /// 安全模块错误
    static func security(_ description: String, code: Int = SystemConstants.HTTPStatusCode.notFound) -> NSError {
        make(domain: CoreConstants.ErrorDomain.securityManager, code: code, description: description)
    }
}

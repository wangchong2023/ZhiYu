//
//  NetworkError+UserMessage.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层（Features/System）
//  核心职责：将 L1 基础设施层的 NetworkError 纯错误码映射为面向用户的本地化文案。
//
//  设计原则（参考 Apple URLError + Alamofire AFError）：
//  - 工具类（NetworkError）只定义纯错误码，不混入本地化字符串
//  - UI 层通过本扩展的 `userMessage` 获取面向终端用户的本地化文案
//  - `errorDescription` 保留为英文调试描述（日志/调试用）
//

import Foundation

public extension NetworkError {
    /// 面向终端用户的本地化错误文案
    ///
    /// UI 层应使用 `error.userMessage` 而非 `error.localizedDescription`，
    /// 以确保用户看到的是经过本地化的友好文案，而非英文调试描述。
    var userMessage: String {
        switch self {
        case .invalidURL:
            return L10n.Network.errorInvalidURL
        case .tokenExpired:
            return L10n.Network.errorTokenExpired
        case .unauthorized(let msg):
            return L10n.Network.errorUnauthorized(msg)
        case .serverError(let code, let msg):
            return L10n.Network.errorServer(code, msg)
        case .decodeFailed(let err):
            return L10n.Network.errorDecodeFailed(err.localizedDescription)
        case .httpError(let code):
            return L10n.Network.errorHTTP(code)
        case .unexpected(let msg):
            return L10n.Network.errorUnexpected(msg)
        case .invalidHTTPResponse:
            return L10n.Network.invalidHTTPResponse
        case .missingDataPayload:
            return L10n.Network.missingDataPayload
        case .missingRefreshToken:
            return L10n.Network.missingRefreshToken
        case .sessionInvalidated:
            return L10n.Network.sessionInvalidated
        case .invalidFileName:
            return L10n.Network.invalidFileName
        }
    }
}

//
//  ApiResponse.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：映射后端全局统一的 JSON 响应格式。
//

import Foundation

/// 后端全局统一 JSON 响应封装
public struct ApiResponse<T: Codable>: Codable, Sendable {
    /// 业务状态码。0 表示操作成功；非 0 表示业务异常
    public let code: Int
    /// 友好可读的错误说明或状态描述
    public let message: String
    /// 业务返回的载荷实体
    public let data: T?
    /// 本次请求的唯一追踪 ID（Trace ID）
    public let requestId: String
    /// 服务端响应的毫秒级时间戳
    public let timestamp: Int64
    
    /// 判断业务请求是否成功
    public var isSuccess: Bool {
        return code == 0
    }
}

/// 当接口响应中 data 为 null 时的占位类型
public struct EmptyData: Codable, Sendable {}

/// 后端网络通信自定义错误
///
/// 设计原则（参考 Apple `URLError` + Alamofire `AFError`）：
/// - 工具类只定义纯错误码，不混入本地化字符串（L10n）
/// - `errorDescription` 返回英文调试描述，仅用于日志/调试
/// - UI 层通过 `NetworkError+UserMessage.userMessage` 获取面向用户的本地化文案
public enum NetworkError: Error, LocalizedError, Sendable {
    case invalidURL
    case tokenExpired          // 40101 (需要无感刷新)
    case unauthorized(String)  // 其他 401 错误 (如伪造/禁用等)
    case serverError(Int, String) // 业务报错 (非 0 code)
    case decodeFailed(Error)
    case httpError(Int)
    case unexpected(String)
    // 纯错误码 case（不携带本地化字符串，参考 Alamofire AFError 模式）
    case invalidHTTPResponse
    case missingDataPayload
    case missingRefreshToken
    case sessionInvalidated

    public var errorDescription: String? {
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
        }
    }
}

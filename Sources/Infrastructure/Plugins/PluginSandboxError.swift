//
//  PluginSandboxError.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：插件系统：JavaScript 沙箱、市场服务、插件注册与生命周期。
//
import Foundation

/// 插件沙盒环境下的安全边界与运行异常错误枚举
public enum PluginSandboxError: Error, LocalizedError {
    /// 目标 URL 无效
    case invalidURL(String)
    /// 域名未在白名单中 (DLP 拦截)
    case dlpFetchBlocked(String)
    /// 请求体或持久化数据超过最大载荷限制
    case payloadTooLarge
    /// 存储键长度超限
    case keyLengthExceeded(Int)
    /// 插件环境执行超时
    case timeout
    /// 预处理异常
    case preProcessException(String)
    /// 后处理异常
    case postProcessException(String)
    /// 数字签名防篡改校验失败
    case invalidSignature
    /// JS 脚本语法不合规
    case scriptSyntaxError(String)
    /// 插件未声明所需权限即尝试调用受保护能力
    case permissionDenied(String)

    // MARK: - 标准 HTTP 风格错误码

    /// HTTP 风格的状态码，兼容已有的 NSError code 体系
    public var statusCode: Int {
        switch self {
        case .invalidURL: return 400
        case .scriptSyntaxError: return 400
        case .dlpFetchBlocked: return 403
        case .timeout: return 408
        case .preProcessException: return 408
        case .postProcessException: return 408
        case .payloadTooLarge: return 413
        case .keyLengthExceeded: return 400
        case .invalidSignature: return 403
        case .permissionDenied: return 403
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return L10n.Plugin.Error.invalidURL(url)
        case .dlpFetchBlocked(let host):
            return L10n.Plugin.Error.dlpFetchBlocked(host)
        case .payloadTooLarge:
            return L10n.Plugin.Error.payloadTooLarge
        case .keyLengthExceeded(let maxLen):
            return L10n.Plugin.Error.keyLengthExceeded(maxLen)
        case .timeout:
            return L10n.Plugin.Error.preProcessException("Timeout")
        case .preProcessException(let reason):
            return L10n.Plugin.Error.preProcessException(reason)
        case .postProcessException(let reason):
            return L10n.Plugin.Error.postProcessException(reason)
        case .invalidSignature:
            return L10n.Plugin.Error.preProcessException("Invalid signature")
        case .scriptSyntaxError(let detail):
            return L10n.Plugin.Error.preProcessException(detail)
        case .permissionDenied(let permission):
            return L10n.Plugin.Error.permissionDenied(permission)
        }
    }
}

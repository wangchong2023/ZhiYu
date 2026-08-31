//
//  PluginSandboxGateway.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：插件系统：JavaScript 沙箱、市场服务、插件注册与生命周期。
//
import Foundation
import UFPCore
#if os(iOS) || os(macOS) || os(tvOS)
import JavaScriptCore
#endif

#if os(iOS) || os(macOS) || os(tvOS)
/// JS 看门狗超时熔断回调类型，返回 0/1 (Int32)
typealias JSShouldTerminateCallback = @convention(c) (JSContextGroupRef?, UnsafeMutableRawPointer?) -> Int32

@_silgen_name("JSContextGroupSetExecutionTimeLimit")
/// JavaScriptCore 内部 API：设置执行时间限制
func JSContextGroupSetExecutionTimeLimit(
    _ group: JSContextGroupRef?,
    _ limit: Double,
    _ callback: JSShouldTerminateCallback?,
    _ context: UnsafeMutableRawPointer?
)
#endif

/// 插件沙盒双向通信安全网关 (PluginSandboxGateway)
/// 作为 JavaScript 运行环境与 Swift 原生系统的安全屏障，实施全量网络与持久化数据的 DLP 深度审计，并监控运行时资源。
struct PluginSandboxGateway {
    /// 统一物理限制大小：载荷上限（引用 PluginConstants.Sandbox.maxResponseSizeMB * SystemConstants.bytesPerMB）
    private static let maxPayloadSize = PluginConstants.Sandbox.maxResponseSizeMB * Int(SystemConstants.bytesPerMB)
    
    /// 限制本地存储 Key 最大长度
    private static let maxKeyLength = 256

    /// 运行时：单次 JS 调用的最大执行耗时 (秒) (@SR-04)
    private static let executionTimeLimit: Double = AppConfig.pluginTimeoutLimit
    
    // MARK: - 网络请求审计
    
    /// 审计并清洗插件发起的异步 Fetch 请求参数
    /// - Parameters:
    ///   - urlString: 目标 URL
    ///   - options: 附加请求选项 (Headers, Body 等)
    ///   - allowedDomains: 插件 manifest 中声明的允许域名白名单列表
    ///   - permissions: 插件 manifest 中声明的权限列表
    /// - Returns: 净化并构建好的安全 URLRequest
    /// - Throws: 包含权限缺失、域名拦截或大小超限的安全错误说明
    static func auditFetch(url urlString: String, options: [String: Any]?, allowedDomains: [String], permissions: [String] = []) throws -> URLRequest { // swiftlint:disable:this cyclomatic_complexity
        // 权限校验：插件必须声明 network 权限才能发起网络请求
        // 与 requestAIAccess（检查 "llm"）、queryPages（检查 "pages.read"）保持一致
        guard permissions.contains(PluginConstants.Permission.network) else {
            throw PluginSandboxError.permissionDenied(PluginConstants.Permission.network)
        }

        guard let requestURL = URL(string: urlString), let host = requestURL.host else {
            throw PluginSandboxError.invalidURL(urlString)
        }

        // 域名白名单审计（VULN-002 修复：使用精确后缀匹配，杜绝子串绕过）
        let normalizedHost = host.lowercased()
        let isAllowed = allowedDomains.contains { domain in
            let normalizedDomain = domain.lowercased()
            // 拒绝空字符串白名单（空字符串会匹配任意 host）
            guard !normalizedDomain.isEmpty else { return false }
            // 精确匹配或合法子域后缀匹配（".domain" 确保是子域，而非前缀欺骗）
            return normalizedHost == normalizedDomain || normalizedHost.hasSuffix("." + normalizedDomain)
        }
        guard isAllowed else {
            throw PluginSandboxError.dlpFetchBlocked(host)
        }

        var request = URLRequest(url: requestURL)

        if let opts = options {
            let method = (opts["method"] as? String)?.uppercased() ?? "GET"
            // Bug #33 修复：限制 HTTP 方法为安全白名单，拒绝 DELETE/TRACE/CONNECT 等
                guard PluginConstants.NetworkSecurity.allowedHTTPMethods.contains(method) else {
                    throw PluginSandboxError.permissionDenied(PluginConstants.Permission.httpMethod)
                }
            request.httpMethod = method
            if let headers = opts["headers"] as? [String: String] {
                // Bug #32 修复：过滤危险 header，防止插件窃取宿主凭证
                for (key, val) in headers {
                    guard !PluginConstants.NetworkSecurity.blockedHeaders.contains(key) else {
                        throw PluginSandboxError.permissionDenied(PluginConstants.Permission.httpHeader)
                    }
                    request.setValue(val, forHTTPHeaderField: key)
                }
            }
            if let body = opts["body"] as? String {
                guard body.utf8.count <= maxPayloadSize else {
                    throw PluginSandboxError.payloadTooLarge
                }
                request.httpBody = body.data(using: .utf8)
            }
        }
        
        return request
    }
    
    // MARK: - 持久化数据审计
    
    /// 审计并限制插件通过 saveData 持久化在宿主 App 内部的键值对大小
    /// - Parameters:
    ///   - key: 持久化 Key
    ///   - value: 持久化文本数据
    /// - Throws: 包含存储超限的异常错误
    static func auditStorage(key: String, value: String) throws {
        guard key.count <= maxKeyLength else {
            throw PluginSandboxError.keyLengthExceeded(maxKeyLength)
        }

        guard value.utf8.count <= maxPayloadSize else {
            throw PluginSandboxError.payloadTooLarge
        }
    }

    // MARK: - 运行时监控 (Watchdog)
#if os(iOS) || os(macOS) || os(tvOS)
    /// 为 JSContext 配置看门狗护栏，实施 CPU 时间熔断 (@SR-04)
    /// - Parameter context: 目标 JSContext 实例
    static func configureWatchdog(for context: JSContext) {
        let group = JSContextGetGroup(context.jsGlobalContextRef)
        
        // 核心加固：设置 CPU 执行时间限制，防止恶意死循环插件卡死宿主主线程
        // 注意：此 API 属于 JavaScriptCore 内部私有实现，通过 @_silgen_name 桥接使用
        // 使用顶层 C 兼容函数指针，规避 Swift 6 @convention(c) 的捕获限制
        JSContextGroupSetExecutionTimeLimit(group, executionTimeLimit, { _, _ in
            // 顶层 C 函数回调：不捕获任何上下文，仅返回终止码
            return 1
        }, nil)
    }
#endif
}

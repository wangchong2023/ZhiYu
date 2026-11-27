//
//  LLMClient.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：大语言模型客户端：多提供商适配、流式响应解析、端侧推理。
//
import Foundation
import UFPCore

// MARK: - LLM 客户端协议

/// LLM 客户端抽象，支持 Mock 替换
protocol LLMClientProtocol: Sendable {

    /// 发送请求
    /// - Parameter body: body
    func sendRequest(body: [String: Any]) async throws -> [String: Any]

    /// 发送Streaming请求
    /// - Parameter body: body
    func sendStreamingRequest(body: [String: Any]) async throws -> URLSession.AsyncBytes
}

// MARK: - LLM 网络客户端

/// 负责与兼容 OpenAI 协议的 LLM API 进行所有网络通信。
final class LLMClient: LLMClientProtocol, Sendable {

    // MARK: - Properties
    private let baseURL: String
    private let apiKey: String

    // MARK: - Constants
    private static let defaultTimeout: TimeInterval = 30
    private static let streamingTimeout: TimeInterval = 30

    private enum ClientConstants {
        static let retryAttemptDecrement: Int = 1
        static let badGatewayStatusCode: Int = 502
        static let serviceUnavailableStatusCode: Int = 503
        static let gatewayTimeoutStatusCode: Int = 504
        /// 可触发指数退避重试的 5xx 服务端状态码集合
        static let retryableServerStatusCodes: Set<Int> = [
            UFPCore.SystemConstants.HTTPStatusCode.internalServerError,
            badGatewayStatusCode,
            serviceUnavailableStatusCode,
            gatewayTimeoutStatusCode
        ]
        static let chatCompletionsPath = "/chat/completions"
        static let httpMethodPost = "POST"
        static let bearerPrefix = "Bearer "
        static let errorField = "error"
        static let messageField = "message"
        static let emptyString = ""
    }

    // MARK: - Initialization

    /// 初始化 LLM 客户端
    /// - Parameters:
    ///   - baseURL: API 基础路径
    ///   - apiKey: API 密钥
    init(baseURL: String, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    // MARK: - Private Methods

    /// 规范化基础 URL：修剪首尾空白并去除所有尾部斜杠，确保路径拼接与协议校验一致。
    internal var normalizedBaseURL: String {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix(SystemConstants.Character.slash) {
            trimmed.removeLast()
        }
        return trimmed
    }

    // MARK: - Standard Request

    /// 发送非流式对话补全请求 (支持自动重试机制)
    /// - Parameter body: 请求体字典
    /// - Returns: API 响应字典
    /// - Throws: 网络或 API 错误
    func sendRequest(body: [String: Any]) async throws -> [String: Any] {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try await RetryTask.execute(
            maxRetries: LLMConstants.Retry.maxAttempts - ClientConstants.retryAttemptDecrement,
            initialDelay: LLMConstants.Retry.initialDelaySeconds,
            multiplier: LLMConstants.Retry.backoffMultiplier,
            shouldRetry: { error in Self.isRetryableError(error) },
            operation: { [weak self] in
                guard let self else { throw LLMError.invalidResponse }
                return try await self.performRequest(bodyData: bodyData)
            }
        )
    }

    private func performRequest(bodyData: Data) async throws -> [String: Any] {
        let request = try makeLLMRequest(bodyData: bodyData, timeout: Self.defaultTimeout)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if let responseError = Self.mapResponseError(statusCode: httpResponse.statusCode, data: data) {
            throw responseError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse
        }

        return json
    }

    /// 将非 200 响应映射为精准业务错误：401/429 与 5xx 可重试状态码优先映射为对应可识别错误，
    /// 防止网关返回的 500/502/503/504 JSON 错误体被包成 `.apiError` 导致重试机制失效。
    internal static func mapResponseError(statusCode: Int, data: Data) -> LLMError? {
        if statusCode == UFPCore.SystemConstants.HTTPStatusCode.ok {
            return nil
        }
        if statusCode == UFPCore.SystemConstants.HTTPStatusCode.unauthorized {
            return .unauthorized
        }
        if statusCode == UFPCore.SystemConstants.HTTPStatusCode.rateLimited {
            return .rateLimited
        }
        if ClientConstants.retryableServerStatusCodes.contains(statusCode) {
            return .httpError(statusCode)
        }
        if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = errorBody[ClientConstants.errorField] as? [String: Any],
           let message = error[ClientConstants.messageField] as? String {
            return .apiError(message)
        }
        return .httpError(statusCode)
    }

    /// 判断错误是否可重试。
    /// 可重试场景：限流（429）、服务端临时错误（5xx）、网络层断连/超时。
    internal static func isRetryableError(_ error: Error) -> Bool {
        if let llmError = error as? LLMError {
            switch llmError {
            case .rateLimited:
                return true
            case .httpError(let code):
                return ClientConstants.retryableServerStatusCodes.contains(code)
            default:
                return false
            }
        }

        // 处理基础网络错误 (超时、断网等)
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return [NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet].contains(nsError.code)
        }

        return false
    }

    // MARK: - Streaming Request

    /// 发送流式对话补全请求，返回原始 AsyncBytes 流
    /// - Parameter body: 请求体字典
    /// - Returns: 异步字节流
    /// - Throws: 网络或 API 错误
    func sendStreamingRequest(body: [String: Any]) async throws -> URLSession.AsyncBytes {
        let httpBody = try JSONSerialization.data(withJSONObject: body)
        let request = try makeLLMRequest(bodyData: httpBody, timeout: Self.streamingTimeout)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        if let mappedError = Self.mapHTTPStatusError(statusCode: httpResponse.statusCode) {
            throw mappedError
        }

        return bytes
    }

    /// 将非 200 HTTP 状态码映射为精准业务错误（与非流式路径一致：401 -> unauthorized, 429 -> rateLimited）
    internal static func mapHTTPStatusError(statusCode: Int) -> LLMError? {
        if statusCode == UFPCore.SystemConstants.HTTPStatusCode.ok {
            return nil
        }
        if statusCode == UFPCore.SystemConstants.HTTPStatusCode.unauthorized {
            return .unauthorized
        }
        if statusCode == UFPCore.SystemConstants.HTTPStatusCode.rateLimited {
            return .rateLimited
        }
        return .httpError(statusCode)
    }

    // MARK: - 辅助方法

    /// 清洗 API Key 中的换行与控制字符，防御 HTTP Header CRLF 注入
    internal static func sanitizedAPIKey(_ rawKey: String) -> String {
        rawKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.newlines.union(.controlCharacters))
            .joined(separator: ClientConstants.emptyString)
    }

    /// 构造 LLM API 请求 URLRequest（含 HTTPS 强制校验、host/query/fragment 校验与 loopback 豁免）
    /// - Parameters:
    ///   - bodyData: 请求体数据
    ///   - timeout: 超时时间
    /// - Returns: 配置完成的 URLRequest
    /// - Throws: `LLMError.invalidURL` 当 URL 非法、缺少 host、含非法 query/fragment 或非 HTTPS（且非 loopback）
    internal func makeLLMRequest(bodyData: Data, timeout: TimeInterval) throws -> URLRequest {
        // VULN-013 修复 + 审查修复 MED-1: 强制 HTTPS，但对 loopback 地址豁免
        // 本地回环不经过网络，无明文泄露风险，支持本地 LLM 开发（如 Ollama/llama.cpp）
        let lowerURL = normalizedBaseURL.lowercased()
        let isHTTPS = lowerURL.hasPrefix(SystemConstants.URLScheme.https)
        let isLoopback = isLoopbackURL(lowerURL)
        guard isHTTPS || isLoopback else {
            throw LLMError.invalidURL
        }
        guard let components = URLComponents(string: normalizedBaseURL),
              let host = components.host, !host.isEmpty,
              components.query == nil,
              components.fragment == nil,
              let url = URL(string: "\(normalizedBaseURL)\(ClientConstants.chatCompletionsPath)") else {
            throw LLMError.invalidURL
        }

        let cleanAPIKey = Self.sanitizedAPIKey(apiKey)
        var request = URLRequest(url: url)
        request.httpMethod = ClientConstants.httpMethodPost
        request.setValue(SystemConstants.ContentType.applicationJSON, forHTTPHeaderField: SystemConstants.HTTPHeader.contentType)
        request.setValue("\(ClientConstants.bearerPrefix)\(cleanAPIKey)", forHTTPHeaderField: SystemConstants.HTTPHeader.authorization)
        request.timeoutInterval = timeout
        request.httpBody = bodyData
        return request
    }

    /// 审查修复 MED-1 / #142: 严格基于 URL scheme 与 host 精确匹配判断是否为 loopback 地址
    /// 彻底防御 http://localhost.evil.com、http://evil.com/?u=http://localhost、file://localhost 等子串欺骗绕过
    internal func isLoopbackURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              LLMConstants.Loopback.allowedSchemes.contains(scheme),
              let host = url.host?.lowercased() else {
            return false
        }
        return LLMConstants.Loopback.allowedHosts.contains(host)
    }
}

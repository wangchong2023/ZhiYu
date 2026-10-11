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

    /// 规范化基础 URL：去除尾部斜杠以确保路径拼接一致性。
    private var normalizedBaseURL: String {
        baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
    }

    // MARK: - Standard Request

    /// 发送非流式对话补全请求 (支持自动重试机制)
    /// - Parameter body: 请求体字典
    /// - Returns: API 响应字典
    /// - Throws: 网络或 API 错误
    func sendRequest(body: [String: Any]) async throws -> [String: Any] {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try await RetryTask.execute(
            maxRetries: LLMConstants.Retry.maxAttempts - 1,
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

        if httpResponse.statusCode == UFPCore.SystemConstants.HTTPStatusCode.unauthorized { throw LLMError.unauthorized }
        if httpResponse.statusCode == UFPCore.SystemConstants.HTTPStatusCode.rateLimited { throw LLMError.rateLimited }

        guard httpResponse.statusCode == UFPCore.SystemConstants.HTTPStatusCode.ok else {
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorBody["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw LLMError.apiError(message)
            }
            throw LLMError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse
        }

        return json
    }

    /// 判断错误是否可重试。
    /// 可重试场景：限流（429）、服务端临时错误（5xx）、网络层断连/超时。
    private static func isRetryableError(_ error: Error) -> Bool {
        if let llmError = error as? LLMError {
            switch llmError {
            case .rateLimited, .httpError(500), .httpError(502), .httpError(503), .httpError(504):
                return true
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

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == UFPCore.SystemConstants.HTTPStatusCode.ok else {
            throw LLMError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        return bytes
    }

    // MARK: - 辅助方法

    /// 构造 LLM API 请求 URLRequest（含 HTTPS 强制校验与 loopback 豁免）
    /// - Parameters:
    ///   - bodyData: 请求体数据
    ///   - timeout: 超时时间
    /// - Returns: 配置完成的 URLRequest
    /// - Throws: `LLMError.invalidURL` 当 URL 非法或非 HTTPS（且非 loopback）
    private func makeLLMRequest(bodyData: Data, timeout: TimeInterval) throws -> URLRequest {
        // VULN-013 修复 + 审查修复 MED-1: 强制 HTTPS，但对 loopback 地址豁免
        // 本地回环不经过网络，无明文泄露风险，支持本地 LLM 开发（如 Ollama/llama.cpp）
        let lowerURL = normalizedBaseURL.lowercased()
        let isHTTPS = lowerURL.hasPrefix(SystemConstants.URLScheme.https)
        let isLoopback = isLoopbackURL(lowerURL)
        guard isHTTPS || isLoopback else {
            throw LLMError.invalidURL
        }
        guard let url = URL(string: "\(normalizedBaseURL)/chat/completions") else {
            throw LLMError.invalidURL
        }

        let cleanAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SystemConstants.ContentType.applicationJSON, forHTTPHeaderField: SystemConstants.HTTPHeader.contentType)
        request.setValue("Bearer \(cleanAPIKey)", forHTTPHeaderField: SystemConstants.HTTPHeader.authorization)
        request.timeoutInterval = timeout
        request.httpBody = bodyData
        return request
    }

    /// 审查修复 MED-1: 判断 URL 是否为 loopback 地址（本地回环）
    /// loopback 不经过网络，无明文泄露风险，豁免 HTTPS 强制校验
    private func isLoopbackURL(_ urlString: String) -> Bool {
        let lower = urlString.lowercased()
        return lower.contains(LLMConstants.Loopback.localhostMarker) ||
               lower.contains(LLMConstants.Loopback.ipv4LoopbackMarker) ||
               lower.contains(LLMConstants.Loopback.ipv6LoopbackMarker) ||
               lower.contains(LLMConstants.Loopback.anyAddressMarker)
    }
}

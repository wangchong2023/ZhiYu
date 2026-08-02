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
class LLMClient: LLMClientProtocol, @unchecked Sendable {

    // MARK: - Properties
    private let baseURL: String
    private let apiKey: String

    // MARK: - Constants
    private static let defaultTimeout: TimeInterval = 30
    private static let streamingTimeout: TimeInterval = 30
    private static let maxRetries = 3

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
        var lastError: Error?

        for attempt in 0..<Self.maxRetries {
            do {
                return try await performRequest(body: body)
            } catch {
                lastError = error
                // 仅针对网络波动或 429 错误进行重试
                if shouldRetry(error: error, attempt: attempt) {
                    let delay = pow(2.0, Double(attempt)) // 指数退避: 1s, 2s, 4s
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw error
            }
        }
        throw lastError ?? LLMError.invalidResponse
    }

    private func performRequest(body: [String: Any]) async throws -> [String: Any] {
        // VULN-013 修复 + 审查修复 MED-1: 强制 HTTPS，但对 loopback 地址豁免
        // 本地回环不经过网络，无明文泄露风险，支持本地 LLM 开发（如 Ollama/llama.cpp）
        let lowerURL = normalizedBaseURL.lowercased()
        let isHTTPS = lowerURL.hasPrefix("https://")
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(cleanAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = Self.defaultTimeout

        let httpBody = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = httpBody

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if httpResponse.statusCode == 401 { throw LLMError.unauthorized }
        if httpResponse.statusCode == 429 { throw LLMError.rateLimited }

        guard httpResponse.statusCode == 200 else {
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

    /// 判断是否应重试请求。
    /// 可重试场景：限流（429）、服务端临时错误（5xx）、网络层断连/超时。
    /// 使用指数退避策略，最多重试 maxRetries - 1 次。
    private func shouldRetry(error: Error, attempt: Int) -> Bool {
        if attempt >= Self.maxRetries - 1 { return false }

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
        // VULN-013 修复：强制 HTTPS，防止 API key 明文传输
        guard normalizedBaseURL.lowercased().hasPrefix("https://") else {
            throw LLMError.invalidURL
        }
        guard let url = URL(string: "\(normalizedBaseURL)/chat/completions") else {
            throw LLMError.invalidURL
        }

        let cleanAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(cleanAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = Self.streamingTimeout

        let httpBody = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = httpBody

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        return bytes
    }

    // MARK: - 辅助方法

    /// 审查修复 MED-1: 判断 URL 是否为 loopback 地址（本地回环）
    /// loopback 不经过网络，无明文泄露风险，豁免 HTTPS 强制校验
    private func isLoopbackURL(_ urlString: String) -> Bool {
        let lower = urlString.lowercased()
        return lower.contains("://localhost") ||
               lower.contains("://127.0.0.1") ||
               lower.contains("://[::1]") ||
               lower.contains("://0.0.0.0")
    }
}

// MARK: - SSE 解析器

/// 负责从流式响应中解析服务器发送事件 (SSE)。
final class SSEParser {

    /// 解析 SSE 字节流为文本 chunk 序列。
    /// 兼容 OpenAI / DeepSeek / Qwen / Zhipu 等主流提供商的流式格式差异。
    ///
    /// - Parameter bytes: URLSession 异步字节流
    /// - Parameter logger: 可选的诊断日志记录器，用于排查格式兼容问题
    /// - Returns: 逐 chunk 产出的文本流
    static func parse(
        bytes: URLSession.AsyncBytes,
        logger: (any LoggerProtocol)? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var lineCount = 0
                var chunkCount = 0
                var rawLinesForDiagnostic: [String] = []
                do {
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        lineCount += 1
                        logDiagnosticLine(line: line, lineCount: lineCount, logger: logger, rawLines: &rawLinesForDiagnostic)

                        guard let dataString = extractDataString(from: line) else { continue }
                        if dataString == "[DONE]" { break }

                        guard let json = parseJSONLine(dataString, logger: logger) else { continue }
                        if let content = extractContent(from: json) {
                            chunkCount += 1
                            continuation.yield(content)
                        }
                    }

                    if let logger {
                        logger.debug("[SSE] 流结束 — \(lineCount) 行, \(chunkCount) chunk")
                    }
                    continuation.finish()
                } catch {
                    if let logger {
                        logger.error("[SSE] 流解析异常 — 已读 \(lineCount) 行, \(chunkCount) chunk", error: error)
                        if !rawLinesForDiagnostic.isEmpty {
                            logger.debug("[SSE] 异常前收到的原始行:\n\(rawLinesForDiagnostic.joined(separator: "\n"))")
                        }
                    }
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// 诊断日志记录器：仅在前 15 行内记录 SSE 原始行内容供排查格式兼容问题。
    private static func logDiagnosticLine(line: String, lineCount: Int, logger: (any LoggerProtocol)?, rawLines: inout [String]) {
        guard let logger, lineCount <= 15 else { return }
        let preview = String(line.prefix(250))
        rawLines.append(preview)
        if !preview.isEmpty {
            logger.debug("[SSE] L\(lineCount): \(preview)")
        }
    }

    /// 从 SSE 行提取 "data:" 前缀后的内容字符串，兼容 "data: " 和 "data:" 两种格式。
    private static func extractDataString(from line: String) -> String? {
        let dataPrefix = "data:"
        guard line.hasPrefix(dataPrefix) else { return nil }
        return String(line.dropFirst(line.hasPrefix("data: ") ? 6 : 5))
    }

    /// 将 SSE 数据行解析为 JSON 字典，非 JSON 行（如空行、注释）静默跳过。
    private static func parseJSONLine(_ dataString: String, logger: (any LoggerProtocol)?) -> [String: Any]? {
        guard let data = dataString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let logger, !dataString.isEmpty {
                logger.debug("[SSE] 跳过非 JSON 行: \(String(dataString.prefix(120)))")
            }
            return nil
        }
        return json
    }

    /// 从 LLM 响应 JSON 的 choices[0] 中提取 content 或 reasoning_content。
    /// 兼容 delta（流式）和 message（非流式）两种 SSE 结构。
    private static func extractContent(from json: [String: Any]) -> String? {
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first else { return nil }
        let content: String?
        if let delta = first["delta"] as? [String: Any] {
            content = (delta["content"] as? String) ?? (delta["reasoning_content"] as? String)
        } else if let message = first["message"] as? [String: Any] {
            content = (message["content"] as? String) ?? (message["reasoning_content"] as? String)
        } else {
            content = nil
        }
        guard let content, !content.isEmpty else { return nil }
        return content
    }
}

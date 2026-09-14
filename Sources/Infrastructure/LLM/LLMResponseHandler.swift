//
//  LLMResponseHandler.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：LLM 响应处理助手，集中 sendRequest + extractContent 的调用模式，消除多服务间的响应处理重复。
//

import Foundation

/// LLM 响应处理助手 (DRY)
/// 封装 `client.sendRequest(body:)` + `LLMUtils.extractContent(from:)` 的常见组合调用。
enum LLMResponseHandler {
    /// 发送请求并提取响应内容（容错返回空字符串）
    /// - Parameters:
    ///   - client: LLM 客户端
    ///   - body: 请求体字典
    /// - Returns: 提取的响应内容，失败时返回空字符串
    static func sendAndExtract(client: any LLMClientProtocol, body: [String: Any]) async throws -> String {
        let response = try await client.sendRequest(body: body)
        return LLMUtils.extractContent(from: response) ?? ""
    }

    /// 发送请求并提取响应内容（可空返回）
    /// - Parameters:
    ///   - client: LLM 客户端
    ///   - body: 请求体字典
    /// - Returns: 提取的响应内容，失败时返回 nil
    static func sendAndExtractOptional(client: any LLMClientProtocol, body: [String: Any]) async throws -> String? {
        let response = try await client.sendRequest(body: body)
        return LLMUtils.extractContent(from: response)
    }

    /// 发送请求、计算延迟、记录指标并提取响应内容
    /// - Parameters:
    ///   - client: LLM 客户端
    ///   - body: 请求体字典
    ///   - model: 模型标识（用于指标记录）
    ///   - analytics: AI 分析服务
    /// - Returns: 提取的响应内容
    /// - Throws: `LLMError.invalidResponse` 当内容提取失败
    static func sendRecordAndExtract(
        client: any LLMClientProtocol,
        body: [String: Any],
        model: String,
        analytics: AIAnalyticsService
    ) async throws -> String {
        let startTime = Date()
        let response = try await client.sendRequest(body: body)
        let latency = LLMLatencyCalculator.milliseconds(since: startTime)

        analytics.recordUsage(model: model, response: response, latency: latency)

        guard let content = LLMUtils.extractContent(from: response) else {
            throw LLMError.invalidResponse
        }
        return content
    }
}

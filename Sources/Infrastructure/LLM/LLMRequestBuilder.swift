//
//  LLMRequestBuilder.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：LLM API 请求体与消息数组的统一构造工厂，消除多服务间的请求体构造重复。
//

import Foundation

/// LLM 请求体构造工厂 (DRY)
/// 集中管理 OpenAI 兼容 API 的请求体字典与消息数组构造逻辑。
enum LLMRequestBuilder {
    /// 构造单条消息字典
    /// - Parameters:
    ///   - role: 角色标识（system / user / assistant）
    ///   - content: 消息文本内容
    /// - Returns: 标准消息字典 `[role: ..., content: ...]`
    static func message(role: String, content: String) -> [String: String] {
        [LLMConstants.APIKey.role: role, LLMConstants.APIKey.content: content]
    }

    /// 构造 system + user 双消息数组
    /// - Parameters:
    ///   - systemPrompt: 系统提示词
    ///   - userPrompt: 用户提示词
    /// - Returns: 包含 system 与 user 两条消息的数组
    static func systemUserMessages(systemPrompt: String, userPrompt: String) -> [[String: String]] {
        [
            message(role: LLMConstants.Role.system, content: systemPrompt),
            message(role: LLMConstants.Role.user, content: userPrompt)
        ]
    }

    /// 构造仅含单条 user 消息的数组
    /// - Parameter userPrompt: 用户提示词
    /// - Returns: 仅含一条 user 消息的数组
    static func userOnlyMessages(userPrompt: String) -> [[String: String]] {
        [message(role: LLMConstants.Role.user, content: userPrompt)]
    }

    /// 构造基础请求体（含 model 与 messages）
    /// - Parameters:
    ///   - model: 模型标识
    ///   - messages: 消息数组
    ///   - temperature: 采样温度
    ///   - maxTokens: 最大输出 token 数（可选）
    /// - Returns: OpenAI 兼容请求体字典
    static func body(
        model: String,
        messages: [[String: String]],
        temperature: Double,
        maxTokens: Int? = nil
    ) -> [String: Any] {
        var body: [String: Any] = [
            LLMConstants.APIKey.model: model,
            LLMConstants.APIKey.messages: messages,
            LLMConstants.APIKey.temperature: temperature
        ]
        if let maxTokens {
            body[LLMConstants.APIKey.maxTokens] = maxTokens
        }
        return body
    }

    /// 构造含 system + user 双消息的完整请求体
    /// - Parameters:
    ///   - model: 模型标识
    ///   - systemPrompt: 系统提示词
    ///   - userPrompt: 用户提示词
    ///   - temperature: 采样温度
    ///   - maxTokens: 最大输出 token 数（可选）
    /// - Returns: OpenAI 兼容请求体字典
    static func systemUserBody(
        model: String,
        systemPrompt: String,
        userPrompt: String,
        temperature: Double,
        maxTokens: Int? = nil
    ) -> [String: Any] {
        body(
            model: model,
            messages: systemUserMessages(systemPrompt: systemPrompt, userPrompt: userPrompt),
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// 构造仅含单条 user 消息的完整请求体
    /// - Parameters:
    ///   - model: 模型标识
    ///   - userPrompt: 用户提示词
    ///   - temperature: 采样温度
    ///   - maxTokens: 最大输出 token 数（可选）
    /// - Returns: OpenAI 兼容请求体字典
    static func userOnlyBody(
        model: String,
        userPrompt: String,
        temperature: Double,
        maxTokens: Int? = nil
    ) -> [String: Any] {
        body(
            model: model,
            messages: userOnlyMessages(userPrompt: userPrompt),
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
}

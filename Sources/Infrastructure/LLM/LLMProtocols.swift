//
//  LLMProtocols.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：大语言模型客户端：多提供商适配、流式响应解析、端侧推理。
//
import Foundation

/// AI 模型适配器协议
/// 允许系统在本地模型 (Ollama/Llama) 与云端 API (OpenAI/Claude) 之间无缝切换。
protocol LLMAdapter: Sendable {
    var id: String { get }
    var displayName: String { get }

    /// 执行同步生成任务
    func generate(prompt: String, systemPrompt: String) async throws -> String

    /// 执行流式生成任务
    func chatStream(messages: [[String: Any]]) -> AsyncThrowingStream<String, Error>
}

//
//  LLMUtils.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：RAG 检索增强生成管道：语义搜索、链接发现、内容增强、评估。
//
import Foundation

/// 全局共享的 LLM 工具集
enum LLMUtils {
    /// 解析 LLM 输出中的 JSON 字符串数组，自动剥离 Markdown 代码块。
    /// 兼容字符串数组 `["1","0"]` 和数字数组 `[1,0]`（数字会转为字符串）。
    static func parseJSONArray(_ text: String) -> [String] {
        let cleaned = stripMarkdown(text)
        guard let data = cleaned.data(using: .utf8) else { return [] }
        if let array = try? JSONDecoder().decode([String].self, from: data) {
            return array
        }
        if let numbers = try? JSONDecoder().decode([Int].self, from: data) {
            return numbers.map { String($0) }
        }
        return []
    }

    /// 解析 Smart Ingest 结果
    static func parseSmartIngest(_ text: String) -> SmartIngestResult? {
        let cleaned = stripMarkdown(text)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SmartIngestResult.self, from: data)
    }

    /// 解析重构建议
    static func parseRefactorSuggestions(_ text: String) -> [RefactorSuggestion] {
        let cleaned = stripMarkdown(text)
        guard let data = cleaned.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([RefactorSuggestion].self, from: data)) ?? []
    }

    /// 从 LLM 标准响应字典中提取内容文本
    /// 从 OpenAI 兼容 API 响应中提取文本内容。
    /// 兼容标准模型 (message.content) 和推理模型如 DeepSeek v4 Pro (message.reasoning_content)。
    static func extractContent(from response: [String: Any]) -> String? {
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            return nil
        }
        // 优先 content；推理模型（DeepSeek v4 Pro 等）输出走 reasoning_content
        return (message["content"] as? String) ?? (message["reasoning_content"] as? String)
    }

    /// 剥离 Markdown 语法标记（如 ```json 等）并修剪空白。
    static func stripMarkdown(_ text: String) -> String {
        text.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

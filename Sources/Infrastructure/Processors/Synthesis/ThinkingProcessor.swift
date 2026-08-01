//
//  ThinkingProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：思维链（Chain-of-Thought / Thinking）处理引擎：提取 AI 推理思考过程与正式回答。
//

import Foundation

/// 针对大模型思考过程（Reasoning / Thinking）的提取与拆分工具
public enum ThinkingProcessor {

    /// 思考提取结果
    public struct Result: Equatable, Sendable {
        /// AI 思考过程文本（若无则为 nil）
        public let thinkingContent: String?
        /// 剥离思考过程后的正式输出正文
        public let mainContent: String
    }

    /// 提取 AI 回答中的思考过程与正文
    /// - Parameter rawText: 原始回答字符串
    /// - Returns: Result (包含 thinkingContent 和 mainContent)
    public static func process(_ rawText: String) -> Result {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return Result(thinkingContent: nil, mainContent: "")
        }

        // 1. 优先提取 <think>...</think> 或 <thinking>...</thinking> 围栏
        let thinkPatterns = [
            #"(?s)<think>(.*?)</think>"#,
            #"(?s)<thinking>(.*?)</thinking>"#
        ]

        for pattern in thinkPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    if let thinkRange = Range(match.range(at: 1), in: text) {
                        let thinking = String(text[thinkRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let remaining = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        return Result(thinkingContent: thinking.isEmpty ? nil : thinking, mainContent: remaining)
                    }
                }
            }
        }

        // 2. 识别无围栏但顶部有明确“思考过程：”或“Thinking Process:”标记的情况
        let prefixes = ["\u{601D}\u{8003}\u{8FC7}\u{7A0B}：", "\u{601D}\u{8003}\u{8FC7}\u{7A0B}:", "Thinking" + " Process:", "Reasoning:"]
        for prefix in prefixes where text.hasPrefix(prefix) {
            let afterPrefix = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            // 查找思考过程与正文的分界点（如 \n\n 或 正文关键词）
            if let dividerRange = afterPrefix.range(of: "\n\n") {
                let thinking = String(afterPrefix[..<dividerRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let main = String(afterPrefix[dividerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return Result(thinkingContent: thinking.isEmpty ? nil : thinking, mainContent: main)
            }
        }

        // 3. 无思考过程，整段作为正式回答
        return Result(thinkingContent: nil, mainContent: text)
    }
}

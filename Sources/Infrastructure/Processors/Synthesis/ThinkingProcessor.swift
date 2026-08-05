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

        if let res = extractEnclosedThinking(text) {
            return res
        }
        if let res = extractUnclosedThinking(text) {
            return res
        }
        if let res = extractPrefixThinking(text) { return res }
        if let res = extractImplicitCoT(text) { return res }

        return Result(thinkingContent: nil, mainContent: text)
    }

    // MARK: - 私有解析辅助函数

    private static func extractEnclosedThinking(_ text: String) -> Result? {
        for pattern in ProcessorConstants.Thinking.enclosedPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let thinkRange = Range(match.range(at: 1), in: text) {
                let thinking = String(text[thinkRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let remaining = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return Result(thinkingContent: thinking.isEmpty ? nil : thinking, mainContent: remaining)
            }
        }
        return nil
    }

    private static func extractUnclosedThinking(_ text: String) -> Result? {
        for pattern in ProcessorConstants.Thinking.unclosedPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let contentRange = Range(match.range(at: 2), in: text) {
                let content = String(text[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                return Result(thinkingContent: content.isEmpty ? nil : content, mainContent: "")
            }
        }
        return nil
    }

    private static func extractPrefixThinking(_ text: String) -> Result? {
        let lowerText = text.lowercased()
        for prefix in ProcessorConstants.Thinking.prefixes where lowerText.hasPrefix(prefix.lowercased()) {
            let afterPrefix = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if let dividerRange = findAnswerDivider(in: afterPrefix) {
                let thinking = String(afterPrefix[..<dividerRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let main = String(afterPrefix[dividerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return Result(thinkingContent: thinking.isEmpty ? nil : thinking, mainContent: main)
            }
            return Result(thinkingContent: afterPrefix, mainContent: "")
        }
        return nil
    }

    private static func extractImplicitCoT(_ text: String) -> Result? {
        for prefix in ProcessorConstants.Thinking.implicitCoTPrefixes where text.hasPrefix(prefix) {
            if let dividerRange = findAnswerDivider(in: text) {
                let thinking = String(text[..<dividerRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let main = String(text[dividerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !main.isEmpty {
                    return Result(thinkingContent: thinking, mainContent: main)
                }
            }
        }
        return nil
    }

    private static func findAnswerDivider(in text: String) -> Range<String.Index>? {
        for keyword in ProcessorConstants.Thinking.dividerKeywords {
            if let range = text.range(of: keyword),
               let doubleNewline = text[range.lowerBound..<range.upperBound].range(of: ProcessorConstants.Whitespace.doubleNewline) {
                return doubleNewline
            }
        }
        return text.range(of: ProcessorConstants.Whitespace.doubleNewline)
    }
}

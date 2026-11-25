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
            if let (regex, match) = matchFirstCaptureGroup(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators], text: text, captureGroup: 1) {
                let thinking = String(text[match]).trimmingCharacters(in: .whitespacesAndNewlines)
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                let remaining = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return Result(thinkingContent: thinking.isEmpty ? nil : thinking, mainContent: remaining)
            }
        }
        return nil
    }

    private static func extractUnclosedThinking(_ text: String) -> Result? {
        for pattern in ProcessorConstants.Thinking.unclosedPatterns {
            if let (_, match) = matchFirstCaptureGroup(pattern: pattern, options: [.dotMatchesLineSeparators], text: text, captureGroup: 2) {
                let content = String(text[match]).trimmingCharacters(in: .whitespacesAndNewlines)
                return Result(thinkingContent: content.isEmpty ? nil : content, mainContent: "")
            }
        }
        return nil
    }

    /// 共享的正则匹配辅助：构建正则并返回首个匹配的指定捕获组 Range，消除 extractEnclosed/extractUnclosed 间的 regex 样板重复。
    private static func matchFirstCaptureGroup(
        pattern: String,
        options: NSRegularExpression.Options,
        text: String,
        captureGroup: Int
    ) -> (NSRegularExpression, Range<String.Index>)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let captureRange = Range(match.range(at: captureGroup), in: text) else { return nil }
        return (regex, captureRange)
    }

    private static func extractPrefixThinking(_ text: String) -> Result? {
        let lowerText = text.lowercased()
        for prefix in ProcessorConstants.Thinking.prefixes where lowerText.hasPrefix(prefix.lowercased()) {
            let afterPrefix = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if let dividerRange = findAnswerDivider(in: afterPrefix) {
                let (thinking, main) = splitAtDivider(afterPrefix, dividerRange: dividerRange)
                return makeResult(thinking: thinking, main: main)
            }
            return Result(thinkingContent: afterPrefix, mainContent: "")
        }
        return nil
    }

    private static func extractImplicitCoT(_ text: String) -> Result? {
        for prefix in ProcessorConstants.Thinking.implicitCoTPrefixes where text.hasPrefix(prefix) {
            if let dividerRange = findAnswerDivider(in: text) {
                let (thinking, main) = splitAtDivider(text, dividerRange: dividerRange)
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

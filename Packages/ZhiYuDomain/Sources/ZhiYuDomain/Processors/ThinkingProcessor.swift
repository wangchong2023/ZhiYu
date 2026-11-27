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
import UFPCore

/// 针对大模型思考过程（Reasoning / Thinking）的提取与拆分工具
public enum ThinkingProcessor {

    private enum Constants {
        static let fullMatchGroup: Int = 0
        static let enclosedCaptureGroup: Int = 1
        static let unclosedCaptureGroup: Int = 2
        static let emptyString = ""
        static let crlf = SystemConstants.Character.carriageReturn + SystemConstants.Character.newline
    }

    /// 思考提取结果
    public struct Result: Equatable, Sendable {
        /// AI 思考过程文本（若无则为 nil）
        public let thinkingContent: String?
        /// 剥离思考过程后的正式输出正文
        public let mainContent: String

        public init(thinkingContent: String?, mainContent: String) {
            self.thinkingContent = thinkingContent
            self.mainContent = mainContent
        }
    }

    /// 提取 AI 回答中的思考过程与正文
    /// - Parameter rawText: 原始回答字符串
    /// - Returns: Result (包含 thinkingContent 和 mainContent)
    public static func process(_ rawText: String) -> Result {
        // 归一化 CRLF / CR 为 LF，确保 `\n\n` 段落分隔符与多行正则在 Windows 换行下同样生效
        let text = rawText
            .replacingOccurrences(of: Constants.crlf, with: ProcessorConstants.Whitespace.newline)
            .replacingOccurrences(of: SystemConstants.Character.carriageReturn, with: ProcessorConstants.Whitespace.newline)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return Result(thinkingContent: nil, mainContent: Constants.emptyString)
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
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in ProcessorConstants.Thinking.enclosedPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
                continue
            }
            let matches = regex.matches(in: text, options: [], range: fullRange)
            guard !matches.isEmpty else { continue }

            // 收集全部闭合思考块并拼接，防止多段 `<think>` 场景下后续思考内容被静默删除丢失
            let thinkingParts = matches.compactMap { match -> String? in
                guard let captureRange = Range(match.range(at: Constants.enclosedCaptureGroup), in: text) else { return nil }
                let segment = String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                return segment.isEmpty ? nil : segment
            }
            let combinedThinking = thinkingParts.joined(separator: ProcessorConstants.Whitespace.doubleNewline)
            let remaining = regex.stringByReplacingMatches(in: text, options: [], range: fullRange, withTemplate: Constants.emptyString)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Result(thinkingContent: combinedThinking.isEmpty ? nil : combinedThinking, mainContent: remaining)
        }
        return nil
    }

    private static func extractUnclosedThinking(_ text: String) -> Result? {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in ProcessorConstants.Thinking.unclosedPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators, .anchorsMatchLines]),
                  let match = regex.firstMatch(in: text, options: [], range: fullRange),
                  let captureRange = Range(match.range(at: Constants.unclosedCaptureGroup), in: text),
                  let matchRange = Range(match.range(at: Constants.fullMatchGroup), in: text) else {
                continue
            }
            let content = String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            // 保留未闭合 `<think>` 之前已输出的前置正文，避免流式输出中途闪烁丢失
            let leadingMain = String(text[..<matchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            return Result(thinkingContent: content.isEmpty ? nil : content, mainContent: leadingMain)
        }
        return nil
    }

    private static func extractPrefixThinking(_ text: String) -> Result? {
        let lowerText = text.lowercased()
        for prefix in ProcessorConstants.Thinking.prefixes where lowerText.hasPrefix(prefix.lowercased()) {
            let afterPrefix = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if let dividerRange = findAnswerDivider(in: afterPrefix) {
                let (thinking, main) = splitAtDivider(afterPrefix, dividerRange: dividerRange)
                return makeResult(thinking: thinking, main: main)
            }
            return makeResult(thinking: afterPrefix, main: "")
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

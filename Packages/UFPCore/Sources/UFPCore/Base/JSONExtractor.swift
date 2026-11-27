//
//  JSONExtractor.swift
//  UFPCore
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：从 LLM 返回文本中提取第一个完整 JSON 对象（花括号配对 + 字符串转义感知）。
//
import Foundation

/// JSON 对象提取工具
public enum JSONExtractor {
    /// 从文本中提取第一个完整 JSON 对象字符串
    /// - Parameter text: 含 JSON 的文本（可能包含 markdown 代码块包裹）
    /// - Returns: 第一个完整 JSON 对象字符串，找不到返回 nil
    public static func extractFirstJSONObject(from text: String) -> String? {
        extractNextJSONObject(from: text, startingAt: text.startIndex)?.json
    }

    /// 从指定位置向后提取下一个花括号配对完整的 `{...}` 片段及其结束索引
    private static func extractNextJSONObject(
        from text: String,
        startingAt start: String.Index
    ) -> (json: String, nextIndex: String.Index)? {
        let openBrace = SystemConstants.Character.openBrace
        let closeBrace = SystemConstants.Character.closeBrace
        let backslash = SystemConstants.Character.backslash
        let doubleQuote = SystemConstants.Character.doubleQuote
        guard let firstBrace = text[start...].firstIndex(of: Character(openBrace)) else { return nil }
        var depth = 0
        var inString = false
        var escape = false
        var index = firstBrace
        while index < text.endIndex {
            let char = String(text[index])
            if inString {
                if escape {
                    escape = false
                } else if char == backslash {
                    escape = true
                } else if char == doubleQuote {
                    inString = false
                }
            } else if char == doubleQuote {
                inString = true
            } else if char == openBrace {
                depth += 1
            } else if char == closeBrace {
                depth -= 1
                if depth == 0 {
                    let nextIdx = text.index(after: index)
                    return (String(text[firstBrace...index]), nextIdx)
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    /// 从文本中提取第一个合法 JSON 对象并解析为字典（自动跳过前置说明文字中的 `{占位符}` 非法对象）
    /// - Parameter text: 含 JSON 的文本
    /// - Returns: 解析后的字典，失败返回空字典
    public static func extractJSONDictionary(from text: String) -> [String: Any] {
        let stripped = text
            .replacingOccurrences(of: SystemConstants.MarkdownSyntax.jsonCodeFence, with: "", options: .caseInsensitive)
            .replacingOccurrences(of: SystemConstants.MarkdownSyntax.codeFence, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var cursor = stripped.startIndex
        while cursor < stripped.endIndex,
              let candidate = extractNextJSONObject(from: stripped, startingAt: cursor) {
            if let data = candidate.json.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj
            }
            cursor = candidate.nextIndex
        }
        return [:]
    }
}

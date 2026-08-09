//
//  JSONExtractor.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：从 LLM 返回文本中提取第一个完整 JSON 对象（花括号配对 + 字符串转义感知）。
//
import Foundation
import UFPCore

/// JSON 对象提取工具
public enum JSONExtractor {
    /// 从文本中提取第一个完整 JSON 对象字符串
    /// - Parameter text: 含 JSON 的文本（可能包含 markdown 代码块包裹）
    /// - Returns: 第一个完整 JSON 对象字符串，找不到返回 nil
    public static func extractFirstJSONObject(from text: String) -> String? {
        let openBrace = SystemConstants.Character.openBrace
        let closeBrace = SystemConstants.Character.closeBrace
        let backslash = SystemConstants.Character.backslash
        let doubleQuote = SystemConstants.Character.doubleQuote
        guard let firstBrace = text.firstIndex(of: Character(openBrace)) else { return nil }
        var depth = 0
        var inString = false
        var escape = false
        var index = firstBrace
        while index < text.endIndex {
            let char = String(text[index])
            if escape {
                escape = false
            } else if char == backslash {
                escape = true
            } else if char == doubleQuote {
                inString.toggle()
            } else if !inString {
                if char == openBrace { depth += 1 } else if char == closeBrace {
                    depth -= 1
                    if depth == 0 {
                        return String(text[firstBrace...index])
                    }
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    /// 从文本中提取第一个完整 JSON 对象并解析为字典
    /// - Parameter text: 含 JSON 的文本
    /// - Returns: 解析后的字典，失败返回空字典
    public static func extractJSONDictionary(from text: String) -> [String: Any] {
        let stripped = text
            .replacingOccurrences(of: SystemConstants.MarkdownSyntax.jsonCodeFence, with: "")
            .replacingOccurrences(of: SystemConstants.MarkdownSyntax.codeFence, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonStr = extractFirstJSONObject(from: stripped),
              let data = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }
}

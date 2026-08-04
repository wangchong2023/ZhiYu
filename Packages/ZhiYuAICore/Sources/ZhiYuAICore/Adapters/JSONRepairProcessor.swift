//
//  JSONRepairProcessor.swift
//  ZhiYuAICore
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层 → ZhiYuAICore SPM Package (物理归位)
//  核心职责：开源 JSON 语法自愈适配器（双层防护）。
//           - 第一层：SwiftJSONSanitizer - 修复语法缺陷（缺失引号、不匹配括号）
//           - 第二层：PartialJSON.parse() - 处理 LLM 流式截断 JSON，容错补齐为合规 JSON 字符串
//           两层均通过则直接返回，均失败则返回原始字符串供 Markdown 降级解析。
//
//  架构原则：开源库（SwiftJSONSanitizer / PartialJSON）只在此适配层 import，
//            上层通过 import ZhiYuAICore 调用 JSONRepairProcessor.repair(_:)，
//            严禁上层直接 import SwiftJSONSanitizer 或 PartialJSON。
//

import Foundation
import SwiftJSONSanitizer
import PartialJSON

/// 开源双层 JSON 自愈适配器
/// 物理归位于 ZhiYuAICore SPM Package，编译器强制上层必须 import ZhiYuAICore 才能调用
public enum JSONRepairProcessor {

    // MARK: - 公开入口

    /// 修复损坏或半截断的 JSON 字符串，使其符合标准 RFC 8259 JSON 规范
    /// 双层防护：先 SwiftJSONSanitizer 语法修复，再 PartialJSON 截断补全
    /// - Parameter rawJSON: 原始或部分损坏的 JSON 字符串
    /// - Returns: 修复后的合规 JSON 字符串
    public static func repair(_ rawJSON: String) -> String {
        var text = rawJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "{}" }

        // 清理 Markdown 代码块包裹符 (如 ```json ... ```)
        text = text
            .replacingOccurrences(of: #"^```(?:json)?\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 提取最外层 JSON 结构边界
        if let firstBrace = text.firstIndex(where: { $0 == "{" || $0 == "[" }),
           let lastBrace = text.lastIndex(where: { $0 == "}" || $0 == "]" }),
           firstBrace <= lastBrace {
            text = String(text[firstBrace...lastBrace])
        }

        // 预处理 0：补齐未加引号的 key（SwiftJSONSanitizer 不处理此情况）
        // 匹配形如 `  keyName:` 或 `{keyName:` 的裸 key，仅当 keyName 是合法标识符时补齐双引号
        text = quoteUnquotedKeys(text)

        // 第一层：SwiftJSONSanitizer — 语法缺陷修复（括号不匹配、数组尾逗号等）
        let sanitized = SwiftJSONSanitizer.sanitize(text, options: .minify)

        // 预处理 1：移除对象尾逗号 `,}`（SwiftJSONSanitizer 仅移除数组尾逗号 `,]`）
        // 注意：不能用 .regularExpression 选项，因为 } 在正则中是特殊字符会导致匹配失败
        let result = sanitized
            .replacingOccurrences(of: ",}", with: "}")
            .replacingOccurrences(of: ",\n}", with: "\n}")
            .replacingOccurrences(of: ",\r\n}", with: "\r\n}")

        // 验证第一层结果是否合规
        if isValidJSON(result) {
            return result
        }

        // 第二层：PartialJSON — 流式截断自愈补全
        if let recovered = recoverWithPartialJSON(text) {
            return recovered
        }

        // 两层均无法修复时，返回语法修复结果（优于原始损坏串）
        return result.isEmpty ? text : result
    }

    // MARK: - 私有辅助

    /// 补齐 JSON 对象中未加引号的裸 key
    /// 仅处理 `keyName:` 形式，其中 keyName 由字母/下划线/数字组成且不以数字开头
    private static func quoteUnquotedKeys(_ text: String) -> String {
        // 正则匹配：在 `{` 或 `,` 之后（允许空白），捕获未加引号的 key 名，后跟 `:`
        // 替换为 `"key":`
        let pattern = #"(?<=\{)(\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*):"#
        let pattern2 = #"(?<=,)(\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*):"#
        var result = text
        result = result.replacingOccurrences(of: pattern, with: #"$1"$2"$3:"#, options: .regularExpression)
        result = result.replacingOccurrences(of: pattern2, with: #"$1"$2"$3:"#, options: .regularExpression)
        return result
    }

    /// 使用 PartialJSON 将不完整 JSON 解析并序列化为合规字符串
    private static func recoverWithPartialJSON(_ text: String) -> String? {
        guard let parsed = try? PartialJSON.parse(text),
              let data = try? JSONSerialization.data(withJSONObject: parsed),
              let recovered = String(data: data, encoding: .utf8) else {
            return nil
        }
        return recovered
    }

    /// 验证字符串是否符合标准 JSON 格式
    private static func isValidJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            return false
        }
        return true
    }
}

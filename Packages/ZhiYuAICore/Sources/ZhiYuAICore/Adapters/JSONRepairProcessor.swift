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

        // 第一层：SwiftJSONSanitizer — 语法缺陷修复（括号不匹配、尾部逗号等）
        let sanitized = SwiftJSONSanitizer.sanitize(text, options: .minify)

        // 验证第一层结果是否合规
        if isValidJSON(sanitized) {
            return sanitized
        }

        // 第二层：PartialJSON — 流式截断自愈补全
        if let recovered = recoverWithPartialJSON(text) {
            return recovered
        }

        // 两层均无法修复时，返回语法修复结果（优于原始损坏串）
        return sanitized.isEmpty ? text : sanitized
    }

    // MARK: - 私有辅助

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

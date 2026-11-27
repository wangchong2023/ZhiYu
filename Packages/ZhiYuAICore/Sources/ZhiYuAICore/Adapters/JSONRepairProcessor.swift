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

    private enum JSONToken {
        static let backslash: Character = "\\"
        static let doubleQuote: Character = "\""
        static let comma: Character = ","
        static let openingBrace: Character = "{"
        static let closingBrace: Character = "}"
        static let openingBracket: Character = "["
        static let closingBracket: Character = "]"
        static let emptyJSONObject: String = "{}"
        static let colon: Character = ":"
        static let underscore: Character = "_"
        static let space: Character = " "
        static let tab: Character = "\t"
        static let lineFeed: Character = "\n"
        static let carriageReturn: Character = "\r"
    }

    // MARK: - 公开入口

    /// 修复损坏或半截断的 JSON 字符串，使其符合标准 RFC 8259 JSON 规范
    /// 双层防护：先 SwiftJSONSanitizer 语法修复，再 PartialJSON 截断补全
    /// - Parameter rawJSON: 原始或部分损坏的 JSON 字符串
    /// - Returns: 修复后的合规 JSON 字符串
    public static func repair(_ rawJSON: String) -> String {
        var text = rawJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return JSONToken.emptyJSONObject }

        // 清理 Markdown 代码块包裹符 (如 ```json ... ```)
        text = text
            .replacingOccurrences(of: #"^```(?:json)?\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 提取最外层 JSON 结构边界
        if let firstBrace = text.firstIndex(where: { $0 == JSONToken.openingBrace || $0 == JSONToken.openingBracket }),
           let lastBrace = text.lastIndex(where: { $0 == JSONToken.closingBrace || $0 == JSONToken.closingBracket }),
           firstBrace <= lastBrace {
            text = String(text[firstBrace...lastBrace])
        }

        // 预处理 0：补齐未加引号的 key（SwiftJSONSanitizer 不处理此情况）
        // 匹配形如 `  keyName:` 或 `{keyName:` 的裸 key，仅当 keyName 是合法标识符时补齐双引号
        text = quoteUnquotedKeys(text)

        // 第一层：SwiftJSONSanitizer — 语法缺陷修复（括号不匹配、数组尾逗号等）
        let sanitized = SwiftJSONSanitizer.sanitize(text, options: .minify)

        // 预处理 1：字符串感知移除对象尾逗号（仅在字符串字面量之外移除 `,` + 可选空白 + `}`，避免误伤字符串值内的 `,}`）
        let result = removeTrailingObjectCommas(sanitized)

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
    /// 仅处理 `keyName:` 形式，其中 keyName 由 ASCII 字母/下划线/数字组成且不以数字开头。
    /// 使用字符串感知的状态机而非正则：字符串字面量内部（含转义）整体跳过，
    /// 仅在字符串外对 `{`/`,` 后紧跟的裸 key 补引号，
    /// 避免误伤合法 JSON 的字符串值（如 `{"text": "use, foo: bar"}`）。
    private static func quoteUnquotedKeys(_ text: String) -> String {
        let chars = Array(text)
        var output = ""
        var inString = false
        var escape = false
        var index = 0
        let count = chars.count

        while index < count {
            let char = chars[index]
            if inString {
                output.append(char)
                if escape {
                    escape = false
                } else if char == JSONToken.backslash {
                    escape = true
                } else if char == JSONToken.doubleQuote {
                    inString = false
                }
                index += 1
                continue
            }
            if char == JSONToken.doubleQuote {
                inString = true
                output.append(char)
                index += 1
                continue
            }
            if char == JSONToken.openingBrace || char == JSONToken.comma,
               let nextIndex = tryConsumeUnquotedKey(in: chars, from: index, output: &output) {
                index = nextIndex
                continue
            }
            output.append(char)
            index += 1
        }
        return output
    }

    /// 尝试在 `{` 或 `,` 之后识别并补齐裸 key 引号；匹配成功返回消费后的新下标
    private static func tryConsumeUnquotedKey(in chars: [Character], from index: Int, output: inout String) -> Int? {
        let count = chars.count
        var keyStart = index + 1
        while keyStart < count && isWhitespace(chars[keyStart]) { keyStart += 1 }
        guard keyStart < count, isIdentifierStart(chars[keyStart]) else { return nil }

        var keyEnd = keyStart
        while keyEnd < count && isIdentifierChar(chars[keyEnd]) { keyEnd += 1 }
        var colonIndex = keyEnd
        while colonIndex < count && isWhitespace(chars[colonIndex]) { colonIndex += 1 }
        guard colonIndex < count, chars[colonIndex] == JSONToken.colon else { return nil }

        output.append(chars[index])
        output.append(contentsOf: chars[(index + 1)..<keyStart])
        output.append(JSONToken.doubleQuote)
        output.append(contentsOf: chars[keyStart..<keyEnd])
        output.append(JSONToken.doubleQuote)
        return keyEnd
    }

    /// 是否为 JSON 裸 key 起始字符（ASCII 字母或下划线）
    private static func isIdentifierStart(_ char: Character) -> Bool {
        char.isASCII && (char.isLetter || char == JSONToken.underscore)
    }

    /// 是否为 JSON 裸 key 组成字符（ASCII 字母/数字/下划线）
    private static func isIdentifierChar(_ char: Character) -> Bool {
        char.isASCII && (char.isLetter || char.isNumber || char == JSONToken.underscore)
    }

    /// 是否为 JSON 空白字符
    private static func isWhitespace(_ char: Character) -> Bool {
        char == JSONToken.space
            || char == JSONToken.tab
            || char == JSONToken.lineFeed
            || char == JSONToken.carriageReturn
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

    /// 字符串感知移除对象尾逗号（仅在 JSON 字符串外部、`,` 跳过空白后紧跟 `}` 时删除逗号，绝不篡改字符串值内的 `,}`）
    private static func removeTrailingObjectCommas(_ text: String) -> String {
        let chars = Array(text)
        let count = chars.count
        var output = ""
        output.reserveCapacity(count)
        var inString = false
        var escape = false

        for index in 0..<count {
            let char = chars[index]
            if inString {
                output.append(char)
                if escape {
                    escape = false
                } else if char == JSONToken.backslash {
                    escape = true
                } else if char == JSONToken.doubleQuote {
                    inString = false
                }
                continue
            }
            if char == JSONToken.doubleQuote {
                inString = true
                output.append(char)
                continue
            }
            if char == JSONToken.comma, isFollowedByClosingBrace(in: chars, after: index) {
                continue
            }
            output.append(char)
        }
        return output
    }

    /// 判断下标 `index` 之后跳过空白字符是否紧跟 `}`
    private static func isFollowedByClosingBrace(in chars: [Character], after index: Int) -> Bool {
        var lookahead = index + 1
        while lookahead < chars.count && isWhitespace(chars[lookahead]) {
            lookahead += 1
        }
        return lookahead < chars.count && chars[lookahead] == JSONToken.closingBrace
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

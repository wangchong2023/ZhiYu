//
//  FrontmatterParser.swift
//  ZhiYuDomain
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuDomain]
//  核心职责：从 Markdown 源码剥离头部 Frontmatter（--- / ---json）与正文 Body，并提供
//           简易 YAML→JSON 转换与泛型解码。纯 Foundation/UFPCore 工具，无 App 层依赖。
//

import Foundation
import UFPCore

/// Frontmatter 解析器 (通用剥离)
/// 负责从 Markdown 源码剥离头部 Frontmatter 与正文，以及简易 YAML→JSON 转换。
/// 具体的 `XxxFrontmatter` 业务模型（ConceptFrontmatter / EntityFrontmatter 等）由 App 业务层持有，
/// 此处仅保留通用剥离逻辑。
public enum FrontmatterParser {

    /// 从 Markdown 源码中剥离头部 Frontmatter (--- 或 ---json 标志包围的部分) 与正文 Body
    /// - Parameter content: Markdown 原始字符串
    /// - Returns: 元组 (frontmatterString, bodyString)
    public static func split(content: String) -> (frontmatter: String?, body: String) {
        // 剥离可选 UTF-8 BOM 并归一化 CRLF/CR 为 LF，避免 Windows Markdown 产生空行或首行识别失败
        let withoutBOM = content.hasPrefix(utf8BOM) ? String(content.dropFirst()) : content
        let normalizedContent = withoutBOM
            .replacingOccurrences(of: crlf, with: SystemConstants.Character.newline)
            .replacingOccurrences(of: SystemConstants.Character.carriageReturn, with: SystemConstants.Character.newline)
        let lines = normalizedContent.components(separatedBy: SystemConstants.Character.newline)

        // 必须顶格以 --- 或 ---json 开头（禁止前置缩进空格）
        guard let firstLine = lines.first,
              firstLine == SystemConstants.MarkdownDelimiter.horizontalRule
                || firstLine == jsonDelimiter else {
            return (nil, content)
        }

        var frontmatterLines: [String] = []
        var bodyLines: [String] = []
        var foundEnd = false

        for index in 1..<lines.count {
            let line = lines[index]
            if !foundEnd && line == SystemConstants.MarkdownDelimiter.horizontalRule {
                foundEnd = true
                continue
            }
            if foundEnd {
                bodyLines.append(line)
            } else {
                frontmatterLines.append(line)
            }
        }

        if !foundEnd {
            // 如果没找到结尾的 ---，说明整个 Markdown 不包含有效的 Frontmatter
            return (nil, content)
        }

        let fmString = frontmatterLines
            .joined(separator: SystemConstants.Character.newline)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyString = bodyLines.joined(separator: SystemConstants.Character.newline)
        return (fmString.isEmpty ? nil : fmString, bodyString)
    }

    /// 将提取出的 Frontmatter 字符串解析为指定强类型
    /// - Parameters:
    ///   - type: 期望的目标模型
    ///   - frontmatter: 剥离出的 Frontmatter 文本
    /// - Returns: 解码后的 Decodable 模型，解析失败返回 nil
    public static func parse<T: Decodable>(_ type: T.Type, from frontmatter: String) -> T? {
        let trimmed = frontmatter.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 优先作为 JSON 进行解析
        if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
            if let data = trimmed.data(using: .utf8) {
                let decoder = JSONDecoder()
                do {
                    return try decoder.decode(type, from: data)
                } catch {
                    MinimalLogger.shared.warning("[FrontmatterParser] JSON 直接解析失败: \(error.localizedDescription)")
                }
            }
        }

        // 2. 如果是 YAML 格式，做简易的 YAML 转 JSON 并尝试重新解析
        let jsonString = convertYamlToJson(trimmed)
        if let data = jsonString.data(using: .utf8) {
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(type, from: data)
            } catch {
                MinimalLogger.shared.warning("[FrontmatterParser] YAML 降级转换为 JSON 后解析失败: \(error.localizedDescription)")
            }
        }

        return nil
    }

    /// ---json 标志分隔符
    private static let jsonDelimiter: String = "---json"

    /// 简易的 YAML-to-JSON 转换器，支持 key: value 顶层键值与数组项对象。
    /// 注意：暂不支持真正的嵌套 dict（如 `author:\n  name: x` 会被扁平化为独立顶层对象，
    /// 而非挂到父键 `author` 下）；如确有嵌套 frontmatter 需求，需引入嵌套栈解析器。
    private static func convertYamlToJson(_ yaml: String) -> String {
        let normalizedYaml = yaml
            .replacingOccurrences(of: crlf, with: SystemConstants.Character.newline)
            .replacingOccurrences(of: SystemConstants.Character.carriageReturn, with: SystemConstants.Character.newline)
        let lines = normalizedYaml.components(separatedBy: SystemConstants.Character.newline)
        var dict: [String: Any] = [:]

        var currentArrayKey: String?
        var currentArray: [[String: Any]] = []
        var currentScalarArray: [String] = []
        var currentObject: [String: Any] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix(SystemConstants.Character.hash) { continue }

            if trimmed.hasPrefix(SystemConstants.Character.dash) {
                processArrayItemLine(
                    trimmed,
                    currentObject: &currentObject,
                    currentArray: &currentArray,
                    currentScalarArray: &currentScalarArray
                )
                continue
            }

            if line.hasPrefix(doubleSpace) || line.hasPrefix(quadSpace) {
                parseKeyValue(trimmed, into: &currentObject)
                continue
            }

            processTopLevelLine(
                trimmed,
                dict: &dict,
                currentArrayKey: &currentArrayKey,
                currentArray: &currentArray,
                currentScalarArray: &currentScalarArray,
                currentObject: &currentObject
            )
        }

        finalizeConversion(
            dict: &dict,
            currentArrayKey: &currentArrayKey,
            currentArray: &currentArray,
            currentScalarArray: &currentScalarArray,
            currentObject: &currentObject
        )

        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let jsonStr = String(data: jsonData, encoding: .utf8) {
            return jsonStr
        }
        return emptyJSONObject
    }

    private static func processArrayItemLine(
        _ trimmed: String,
        currentObject: inout [String: Any],
        currentArray: inout [[String: Any]],
        currentScalarArray: inout [String]
    ) {
        flushCurrentObject(into: &currentArray, currentObject: &currentObject)
        let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        if content.contains(SystemConstants.Character.colon) {
            parseKeyValue(content, into: &currentObject)
        } else {
            currentScalarArray.append(stripSurroundingQuotes(content))
        }
    }

    private static func processTopLevelLine(
        _ trimmed: String,
        dict: inout [String: Any],
        currentArrayKey: inout String?,
        currentArray: inout [[String: Any]],
        currentScalarArray: inout [String],
        currentObject: inout [String: Any]
    ) {
        flushCurrentObject(into: &currentArray, currentObject: &currentObject)

        if let arrayKey = currentArrayKey {
            if !currentArray.isEmpty {
                dict[arrayKey] = currentArray
                currentArray = []
            } else if !currentScalarArray.isEmpty {
                dict[arrayKey] = currentScalarArray
                currentScalarArray = []
            }
            currentArrayKey = nil
        }

        let parts = trimmed.split(separator: Character(SystemConstants.Character.colon), maxSplits: singleSplitCount, omittingEmptySubsequences: false)
        guard parts.count == keyValuePairCount else { return }
        let key = parts[keyPartIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let valueStr = parts[valuePartIndex].trimmingCharacters(in: .whitespacesAndNewlines)

        if valueStr.isEmpty {
            currentArrayKey = key
        } else {
            parseAndInsertValue(key: key, valueStr: valueStr, dict: &dict)
        }
    }

    private static func parseAndInsertValue(key: String, valueStr: String, dict: inout [String: Any]) {
        if isWrappedInMatchingQuotes(valueStr) {
            // 显式引号包裹的标量始终按字符串保留，避免 `"123"` / `"true"` 被误强转为数字或布尔
            dict[key] = stripSurroundingQuotes(valueStr)
        } else if valueStr.hasPrefix(SystemConstants.Character.openBracket) && valueStr.hasSuffix(SystemConstants.Character.closeBracket) {
            let arrayContent = String(valueStr.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if arrayContent.isEmpty {
                dict[key] = [String]()
            } else {
                let items = arrayContent
                    .components(separatedBy: SystemConstants.Character.comma)
                    .map { stripSurroundingQuotes($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    .filter { !$0.isEmpty }
                dict[key] = items
            }
        } else if let num = Double(valueStr), num.isFinite {
            dict[key] = num
        } else if valueStr == SystemConstants.BooleanLiteral.true {
            dict[key] = true
        } else if valueStr == SystemConstants.BooleanLiteral.false {
            dict[key] = false
        } else {
            dict[key] = stripSurroundingQuotes(valueStr)
        }
    }

    private static func finalizeConversion(
        dict: inout [String: Any],
        currentArrayKey: inout String?,
        currentArray: inout [[String: Any]],
        currentScalarArray: inout [String],
        currentObject: inout [String: Any]
    ) {
        flushCurrentObject(into: &currentArray, currentObject: &currentObject, resetObject: false)
        if let arrayKey = currentArrayKey {
            if !currentArray.isEmpty {
                dict[arrayKey] = currentArray
            } else if !currentScalarArray.isEmpty {
                dict[arrayKey] = currentScalarArray
            }
        }
    }

    /// 共享的 currentObject 刷新辅助：将非空 currentObject 追加到 currentArray，消除三处重复的 isEmpty 判断样板。
    /// - Parameters:
    ///   - currentArray: 当前数组输出目标
    ///   - currentObject: 当前对象（追加后按 resetObject 决定是否清空）
    ///   - resetObject: 是否在追加后清空 currentObject（finalizeConversion 不需要清空）
    private static func flushCurrentObject(
        into currentArray: inout [[String: Any]],
        currentObject: inout [String: Any],
        resetObject: Bool = true
    ) {
        if !currentObject.isEmpty {
            currentArray.append(currentObject)
            if resetObject {
                currentObject = [:]
            }
        }
    }

    private static func parseKeyValue(_ content: String, into dict: inout [String: Any]) {
        let parts = content.split(separator: Character(SystemConstants.Character.colon), maxSplits: singleSplitCount, omittingEmptySubsequences: true)
        guard parts.count == keyValuePairCount else { return }
        let key = parts[keyPartIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = parts[valuePartIndex].trimmingCharacters(in: .whitespacesAndNewlines)

        if isWrappedInMatchingQuotes(rawValue) {
            dict[key] = stripSurroundingQuotes(rawValue)
        } else if let num = Double(rawValue), num.isFinite {
            dict[key] = num
        } else if rawValue == SystemConstants.BooleanLiteral.true {
            dict[key] = true
        } else if rawValue == SystemConstants.BooleanLiteral.false {
            dict[key] = false
        } else {
            dict[key] = rawValue
        }
    }

    /// 判断字符串是否被成对双引号或单引号包裹
    private static func isWrappedInMatchingQuotes(_ raw: String) -> Bool {
        guard raw.count >= minimumQuotedLength else { return false }
        let isDoubleQuoted = raw.hasPrefix(SystemConstants.Character.doubleQuote)
            && raw.hasSuffix(SystemConstants.Character.doubleQuote)
        let isSingleQuoted = raw.hasPrefix(SystemConstants.Character.singleQuote)
            && raw.hasSuffix(SystemConstants.Character.singleQuote)
        return isDoubleQuoted || isSingleQuoted
    }

    /// 剥离首尾成对单引号或双引号，并对双引号内的 `\"` / `\\` 执行反转义
    private static func stripSurroundingQuotes(_ raw: String) -> String {
        guard isWrappedInMatchingQuotes(raw) else { return raw }
        let inner = String(raw.dropFirst().dropLast())
        if raw.hasPrefix(SystemConstants.Character.doubleQuote) {
            return inner
                .replacingOccurrences(of: escapedDoubleQuote, with: SystemConstants.Character.doubleQuote)
                .replacingOccurrences(of: escapedBackslash, with: SystemConstants.Character.backslash)
        }
        return inner
    }

    /// 成对引号包裹字符串的最小字符数
    private static let minimumQuotedLength: Int = 2
    private static let singleSplitCount: Int = 1
    private static let keyValuePairCount: Int = 2
    private static let keyPartIndex: Int = 0
    private static let valuePartIndex: Int = 1
    private static let emptyJSONObject: String = "{}"
    private static let utf8BOM: String = "\u{FEFF}"
    private static let crlf: String = SystemConstants.Character.carriageReturn + SystemConstants.Character.newline
    private static let escapedDoubleQuote: String = SystemConstants.Character.backslash + SystemConstants.Character.doubleQuote
    private static let escapedBackslash: String = SystemConstants.Character.backslash + SystemConstants.Character.backslash
    /// YAML 嵌套缩进两个空格
    private static let doubleSpace: String = "  "
    /// YAML 嵌套缩进四个空格
    private static let quadSpace: String = "    "
}

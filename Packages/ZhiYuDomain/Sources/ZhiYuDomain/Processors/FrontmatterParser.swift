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
        let lines = content.components(separatedBy: .newlines)

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

    /// 简易的 YAML-to-JSON 转换器，支持 key: value、数组、嵌套 object 映射
    private static func convertYamlToJson(_ yaml: String) -> String {
        let lines = yaml.components(separatedBy: .newlines)
        var dict: [String: Any] = [:]

        var currentArrayKey: String?
        var currentArray: [[String: Any]] = []
        var currentObject: [String: Any] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix(SystemConstants.Character.hash) { continue }

            if trimmed.hasPrefix(SystemConstants.Character.dash) {
                processArrayItemLine(trimmed, currentObject: &currentObject, currentArray: &currentArray)
                continue
            }

            if line.hasPrefix(doubleSpace) || line.hasPrefix(quadSpace) {
                parseKeyValue(trimmed, into: &currentObject)
                continue
            }

            processTopLevelLine(trimmed, dict: &dict, currentArrayKey: &currentArrayKey, currentArray: &currentArray, currentObject: &currentObject)
        }

        finalizeConversion(dict: &dict, currentArrayKey: &currentArrayKey, currentArray: &currentArray, currentObject: &currentObject)

        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let jsonStr = String(data: jsonData, encoding: .utf8) {
            return jsonStr
        }
        return "{}"
    }

    private static func processArrayItemLine(_ trimmed: String, currentObject: inout [String: Any], currentArray: inout [[String: Any]]) {
        flushCurrentObject(into: &currentArray, currentObject: &currentObject)
        let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        if !content.isEmpty {
            parseKeyValue(content, into: &currentObject)
        }
    }

    private static func processTopLevelLine(
        _ trimmed: String,
        dict: inout [String: Any],
        currentArrayKey: inout String?,
        currentArray: inout [[String: Any]],
        currentObject: inout [String: Any]
    ) {
        flushCurrentObject(into: &currentArray, currentObject: &currentObject)

        if let arrayKey = currentArrayKey, !currentArray.isEmpty {
            dict[arrayKey] = currentArray
            currentArray = []
            currentArrayKey = nil
        }

        let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return }
        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let valueStr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

        if valueStr.isEmpty {
            currentArrayKey = key
        } else {
            parseAndInsertValue(key: key, valueStr: valueStr, dict: &dict)
        }
    }

    private static func parseAndInsertValue(key: String, valueStr: String, dict: inout [String: Any]) {
        if valueStr.hasPrefix("[") && valueStr.hasSuffix("]") {
            let arrayContent = String(valueStr.dropFirst().dropLast())
            let items = arrayContent.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            dict[key] = items
        } else if let num = Double(valueStr) {
            dict[key] = num
        } else if valueStr == SystemConstants.BooleanLiteral.true {
            dict[key] = true
        } else if valueStr == SystemConstants.BooleanLiteral.false {
            dict[key] = false
        } else {
            var cleanVal = valueStr
            if cleanVal.hasPrefix(SystemConstants.Character.doubleQuote) && cleanVal.hasSuffix(SystemConstants.Character.doubleQuote) {
                cleanVal = String(cleanVal.dropFirst().dropLast())
            } else if cleanVal.hasPrefix(SystemConstants.Character.singleQuote) && cleanVal.hasSuffix(SystemConstants.Character.singleQuote) {
                cleanVal = String(cleanVal.dropFirst().dropLast())
            }
            dict[key] = cleanVal
        }
    }

    private static func finalizeConversion(
        dict: inout [String: Any],
        currentArrayKey: inout String?,
        currentArray: inout [[String: Any]],
        currentObject: inout [String: Any]
    ) {
        flushCurrentObject(into: &currentArray, currentObject: &currentObject, resetObject: false)
        if let arrayKey = currentArrayKey, !currentArray.isEmpty {
            dict[arrayKey] = currentArray
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
        let parts = content.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return }
        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        var valueStr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        if valueStr.hasPrefix(SystemConstants.Character.doubleQuote) && valueStr.hasSuffix(SystemConstants.Character.doubleQuote) {
            valueStr = String(valueStr.dropFirst().dropLast())
        } else if valueStr.hasPrefix(SystemConstants.Character.singleQuote) && valueStr.hasSuffix(SystemConstants.Character.singleQuote) {
            valueStr = String(valueStr.dropFirst().dropLast())
        }

        if let num = Double(valueStr) {
            dict[key] = num
        } else {
            dict[key] = valueStr
        }
    }

    /// YAML 嵌套缩进两个空格
    private static let doubleSpace: String = "  "
    /// YAML 嵌套缩进四个空格
    private static let quadSpace: String = "    "
}
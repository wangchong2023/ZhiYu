//
//  FrontmatterParser.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：提供 Markdown 纯文本头部 Frontmatter (YAML/JSON 元数据) 剥离及强类型反序列化解析器。
//

import Foundation

// MARK: - 1. 主题页面 (Concept) 元数据结构
public struct ConceptFrontmatter: Codable, Sendable {
    public struct OutlineNode: Codable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let level: Int
        public let associatedPageID: String?
        
        enum CodingKeys: String, CodingKey {
            case id, title, level
            case associatedPageID = "associated_page_id"
        }
    }
    
    public struct SurprisingInsight: Codable, Sendable {
        public let insightTitle: String
        public let linkedConceptID: String
        public let reason: String
        
        enum CodingKeys: String, CodingKey {
            case insightTitle = "insight_title"
            case linkedConceptID = "linked_concept_id"
            case reason
        }
    }
    
    public let outlines: [OutlineNode]?
    public let surprisingInsights: [SurprisingInsight]?
    
    enum CodingKeys: String, CodingKey {
        case outlines
        case surprisingInsights = "surprising_insights"
    }
}

// MARK: - 2. 词条页面 (Entity) 元数据结构
public struct EntityFrontmatter: Codable, Sendable {
    public struct InfoBoxItem: Codable, Sendable {
        public let key: String
        public let value: String
    }
    
    public let pronunciation: String?
    public let definition: String?
    public let aliases: [String]?
    public let infobox: [InfoBoxItem]?
    public let overview: [String]?
}

// MARK: - 3. 来源页面 (Source) 元数据结构
public struct SourceFrontmatter: Codable, Sendable {
    public struct ExtractedPageRef: Codable, Sendable {
        public let pageID: String
        public let name: String
        public let type: String
        
        enum CodingKeys: String, CodingKey {
            case pageID = "page_id"
            case name, type
        }
    }
    
    public let type: String? // "voice" | "ocr" | "file" | "link"
    public let fileName: String?
    public let fileSize: Int64?
    public let voiceAmplitudeWaveform: [Double]?
    public let transcription: String?
    public let extractedPageIDs: [ExtractedPageRef]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case fileName = "file_name"
        case fileSize = "file_size"
        case voiceAmplitudeWaveform = "voice_amplitude_waveform"
        case transcription
        case extractedPageIDs = "extracted_page_ids"
    }
}

// MARK: - 4. 对比页面 (Comparison) 元数据结构
public struct ComparisonFrontmatter: Codable, Sendable {
    public struct ComparisonSubject: Codable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public struct LogoAsset: Codable, Sendable {
            public let lightURL: String?
            public let darkURL: String?
            
            enum CodingKeys: String, CodingKey {
                case lightURL = "light_url"
                case darkURL = "dark_url"
            }
        }
        public let logoAsset: LogoAsset?
        
        enum CodingKeys: String, CodingKey {
            case id, name
            case logoAsset = "logo_asset"
        }
    }
    
    public struct ComparisonDimension: Codable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public let type: String // "text" | "rating" | "range" | "image_list"
        public let unit: String?
    }
    
    public struct MatrixCell: Codable, Sendable {
        public let subjectID: String
        public let dimensionID: String
        public let value: MatrixValue
        
        enum CodingKeys: String, CodingKey {
            case subjectID = "subject_id"
            case dimensionID = "dimension_id"
            case value
        }
    }
    
    public let subjects: [ComparisonSubject]?
    public let dimensions: [ComparisonDimension]?
    public let matrix: [MatrixCell]?
}

/// 灵活存储对比指标的枚举类型
public enum MatrixValue: Codable, Sendable {
    case text(String)
    case rating(Double)
    case range(min: Double, max: Double)
    case imageList([String])
    case null
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let str = try? container.decode(String.self) {
            self = .text(str)
            return
        }
        if let dbl = try? container.decode(Double.self) {
            self = .rating(dbl)
            return
        }
        if let arr = try? container.decode([String].self) {
            self = .imageList(arr)
            return
        }
        if let rangeDict = try? container.decode([String: Double].self),
           let min = rangeDict["min"], let max = rangeDict["max"] {
            self = .range(min: min, max: max)
            return
        }
        self = .null
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let str):
            try container.encode(str)
        case .rating(let dbl):
            try container.encode(dbl)
        case .imageList(let arr):
            try container.encode(arr)
        case .range(let min, let max):
            try container.encode([ProcessorConstants.Frontmatter.minKey: min, "max": max])
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - 5. Frontmatter 物理解析核心处理器
public enum FrontmatterParser {
    
    /// 从 Markdown 源码中剥离头部 Frontmatter (--- 或 ---json 标志包围的部分) 与正文 Body
    /// - Parameter content: Markdown 原始字符串
    /// - Returns: 元组 (frontmatterString, bodyString)
    public static func split(content: String) -> (frontmatter: String?, body: String) {
        let lines = content.components(separatedBy: .newlines)
        
        // 必须以 --- 或 ---json 开头
        guard let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              firstLine == ProcessorConstants.Frontmatter.yamlDelimiter || firstLine == ProcessorConstants.Frontmatter.jsonDelimiter else {
            return (nil, content)
        }
        
        var frontmatterLines: [String] = []
        var bodyLines: [String] = []
        var foundEnd = false
        
        for index in 1..<lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !foundEnd && trimmed == ProcessorConstants.Frontmatter.yamlDelimiter {
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
        
        let fmString = frontmatterLines.joined(separator: ProcessorConstants.Whitespace.newline).trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyString = bodyLines.joined(separator: ProcessorConstants.Whitespace.newline)
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
                    Logger.shared.warning("[FrontmatterParser] JSON 直接解析失败: \(error.localizedDescription)")
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
                Logger.shared.warning("[FrontmatterParser] YAML 降级转换为 JSON 后解析失败: \(error.localizedDescription)")
            }
        }
        
        return nil
    }
    
    /// 简易的 YAML-to-JSON 转换器，支持 key: value、数组、嵌套 object 映射
    private static func convertYamlToJson(_ yaml: String) -> String {
        let lines = yaml.components(separatedBy: .newlines)
        var dict: [String: Any] = [:]
        
        var currentArrayKey: String?
        var currentArray: [[String: Any]] = []
        var currentObject: [String: Any] = [:]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.hash) { continue }

            if trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.dash) {
                processArrayItemLine(trimmed, currentObject: &currentObject, currentArray: &currentArray)
                continue
            }

            if line.hasPrefix(ProcessorConstants.Whitespace.doubleSpace) || line.hasPrefix(ProcessorConstants.Whitespace.quadSpace) {
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
        if !currentObject.isEmpty {
            currentArray.append(currentObject)
            currentObject = [:]
        }
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
        if !currentObject.isEmpty {
            currentArray.append(currentObject)
            currentObject = [:]
        }
        
        if let arrayKey = currentArrayKey, !currentArray.isEmpty {
            dict[arrayKey] = currentArray
            currentArray = []
            currentArrayKey = nil
        }
        
        let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
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
        } else if valueStr == ProcessorConstants.BoolString.true {
            dict[key] = true
        } else if valueStr == ProcessorConstants.BoolString.false {
            dict[key] = false
        } else {
            var cleanVal = valueStr
            if cleanVal.hasPrefix(ProcessorConstants.MarkdownSyntax.doubleQuote) && cleanVal.hasSuffix(ProcessorConstants.MarkdownSyntax.doubleQuote) {
                cleanVal = String(cleanVal.dropFirst().dropLast())
            } else if cleanVal.hasPrefix(ProcessorConstants.MarkdownSyntax.singleQuote) && cleanVal.hasSuffix(ProcessorConstants.MarkdownSyntax.singleQuote) {
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
        if !currentObject.isEmpty {
            currentArray.append(currentObject)
        }
        if let arrayKey = currentArrayKey, !currentArray.isEmpty {
            dict[arrayKey] = currentArray
        }
    }
    
    private static func parseKeyValue(_ content: String, into dict: inout [String: Any]) {
        let parts = content.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return }
        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        var valueStr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        if valueStr.hasPrefix("\"") && valueStr.hasSuffix("\"") {
            valueStr = String(valueStr.dropFirst().dropLast())
        } else if valueStr.hasPrefix("'") && valueStr.hasSuffix("'") {
            valueStr = String(valueStr.dropFirst().dropLast())
        }
        
        if let num = Double(valueStr) {
            dict[key] = num
        } else {
            dict[key] = valueStr
        }
    }
}

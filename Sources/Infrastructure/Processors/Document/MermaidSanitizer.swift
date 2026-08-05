//
//  MermaidSanitizer.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：Mermaid 语法状态机清洗器（按 mermaid.js 开源规范移植）。
//
import Foundation

/// Mermaid 语法状态机清洗器
public enum MermaidSanitizer {

    /// 使用状态机清洗与修复 Mermaid 节点的语法
    /// - Parameter code: 原始 Mermaid 代码
    /// - Returns: 经转义与结构纠错后的 Mermaid 代码
    public static func sanitize(_ code: String) -> String {
        let lines = code.components(separatedBy: .newlines)
        var sanitizedLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // 保留标题、关键字、结构声明
            if trimmed.hasPrefix("#") || trimmed.hasPrefix("```") || trimmed == "mindmap" || trimmed.hasPrefix("graph") || trimmed.hasPrefix("flowchart") {
                sanitizedLines.append(line)
                continue
            }

            // 对带 [内容] 或 (内容) 的节点文本进行安全转义处理
            let sanitizedLine = sanitizeLineNodes(line)
            sanitizedLines.append(sanitizedLine)
        }

        return sanitizedLines.joined(separator: "\n")
    }

    /// 行级节点文本引用与符号转义
    private static func sanitizeLineNodes(_ line: String) -> String {
        // 缺陷 #11 修复：正则 [^"\]]+ 不允许 ] 字符，导致含嵌套方括号的标签无法匹配
        // 采用两步策略：
        // 1. 先匹配不含 ] 的标准 NodeID[Label]（兼容原有行为）
        // 2. 再匹配含嵌套 ] 的 NodeID[Label[...]]（新增支持）
        let standardRegex = try? NSRegularExpression(pattern: #"([A-Za-z0-9_\-]+)\[([^"\]]+)\]"#)
        let nestedRegex = try? NSRegularExpression(pattern: #"([A-Za-z0-9_\-]+)\[([^"\]]*\[[^\]]*\][^"\]]*)\]"#)
        var result = line

        // 先处理嵌套方括号（更具体的模式优先）
        if let nestedMatches = nestedRegex?.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
            for match in nestedMatches.reversed() {
                guard let idRange = Range(match.range(at: 1), in: line),
                      let labelRange = Range(match.range(at: 2), in: line),
                      let fullRange = Range(match.range(at: 0), in: line) else { continue }

                let nodeID = String(line[idRange])
                let labelText = String(line[labelRange]).trimmingCharacters(in: .whitespaces)

                let specialChars: [Character] = [":", "(", ")", "[", "]"]
                if labelText.contains(where: { specialChars.contains($0) }) {
                    let replacement = "\(nodeID)[\"\(labelText)\"]"
                    result.replaceSubrange(fullRange, with: replacement)
                }
            }
        }

        // 再处理标准节点（在已处理后的 result 上重新匹配）
        if let standardMatches = standardRegex?.matches(in: result, range: NSRange(result.startIndex..., in: result)) {
            for match in standardMatches.reversed() {
                guard let idRange = Range(match.range(at: 1), in: result),
                      let labelRange = Range(match.range(at: 2), in: result),
                      let fullRange = Range(match.range(at: 0), in: result) else { continue }

                let nodeID = String(result[idRange])
                let labelText = String(result[labelRange]).trimmingCharacters(in: .whitespaces)

                let specialChars: [Character] = [":", "(", ")", "[", "]"]
                if labelText.contains(where: { specialChars.contains($0) }) {
                    let replacement = "\(nodeID)[\"\(labelText)\"]"
                    result.replaceSubrange(fullRange, with: replacement)
                }
            }
        }
        return result
    }
}

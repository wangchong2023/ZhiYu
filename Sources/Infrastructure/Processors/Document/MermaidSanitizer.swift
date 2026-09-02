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
            if trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.hash) || trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.codeFence) || trimmed == ProcessorConstants.MermaidSyntax.mindmap || trimmed.hasPrefix(ProcessorConstants.MermaidSyntax.graph) || trimmed.hasPrefix(ProcessorConstants.MermaidSyntax.flowchart) {
                sanitizedLines.append(line)
                continue
            }

            // 对带 [内容] 或 (内容) 的节点文本进行安全转义处理
            let sanitizedLine = sanitizeLineNodes(line)
            sanitizedLines.append(sanitizedLine)
        }

        return sanitizedLines.joined(separator: ProcessorConstants.Whitespace.newline)
    }

    /// 行级节点文本引用与符号转义
    private static func sanitizeLineNodes(_ line: String) -> String {
        // 缺陷 #11 修复：正则 [^"\]]+ 不允许 ] 字符，导致含嵌套方括号的标签无法匹配
        // 采用两步策略：
        // 1. 先匹配含嵌套 ] 的 NodeID[Label[...]]（更具体模式优先）
        // 2. 再匹配不含 ] 的标准 NodeID[Label]（兼容原有行为）
        let nestedRegex = try? NSRegularExpression(pattern: ProcessorConstants.RegexPattern.mermaidNodeNested)
        let standardRegex = try? NSRegularExpression(pattern: ProcessorConstants.RegexPattern.mermaidNodeStandard)
        var result = line

        applyNodeReplacements(in: &result, regex: nestedRegex)
        applyNodeReplacements(in: &result, regex: standardRegex)
        return result
    }

    private static func applyNodeReplacements(in text: inout String, regex: NSRegularExpression?) {
        guard let regex else { return }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let idRange = Range(match.range(at: 1), in: text),
                  let labelRange = Range(match.range(at: 2), in: text),
                  let fullRange = Range(match.range(at: 0), in: text) else { continue }

            let nodeID = String(text[idRange])
            let labelText = String(text[labelRange]).trimmingCharacters(in: .whitespaces)

            if labelText.contains(where: { ProcessorConstants.Synthesis.mermaidSpecialChars.contains($0) }) {
                let replacement = "\(nodeID)\(ProcessorConstants.Synthesis.mermaidQuotedNodeOpen)\(labelText)\(ProcessorConstants.Synthesis.mermaidQuotedNodeClose)"
                text.replaceSubrange(fullRange, with: replacement)
            }
        }
    }
}

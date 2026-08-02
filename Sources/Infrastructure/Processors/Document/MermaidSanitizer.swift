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
        // 匹配 NodeID[Label] 结构
        let bracketRegex = try? NSRegularExpression(pattern: #"([A-Za-z0-9_\-]+)\[([^"\]]+)\]"#)
        var result = line

        if let matches = bracketRegex?.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
            for match in matches.reversed() {
                guard let idRange = Range(match.range(at: 1), in: line),
                      let labelRange = Range(match.range(at: 2), in: line),
                      let fullRange = Range(match.range(at: 0), in: line) else { continue }
                
                let nodeID = String(line[idRange])
                let labelText = String(line[labelRange]).trimmingCharacters(in: .whitespaces)
                
                // 如果包含特殊符号且尚未套引号，自动加双引号
                if labelText.contains(":") || labelText.contains("(") || labelText.contains(")") || labelText.contains("[") || labelText.contains("]") {
                    let replacement = "\(nodeID)[\"\(labelText)\"]"
                    result.replaceSubrange(fullRange, with: replacement)
                }
            }
        }
        return result
    }
}

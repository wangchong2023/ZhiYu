//
//  SynthesisProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：文档处理器：Markdown 解析、文本分块、图谱布局、网页抓取。
//
import Foundation

/// 针对知识合成（思维导图、演示文稿、知识测验、深度报告、信息图）的通用处理工具
enum SynthesisProcessor {

    /// 格式化 Mermaid 代码块
    /// - Parameters:
    ///   - text: 包含 Mermaid 代码的原始文本
    ///   - fallbackPrefix: 当无法自动识别图表类型时的默认前缀
    /// - Returns: 标准化的 Mermaid 代码块，若文本为空或无效则返回空字符串
    static func formatMermaid(_ text: String, fallbackPrefix: String) -> String {
        let cleaned = Self.cleanMermaidDelimiters(text)
        guard !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        let title = Self.extractMermaidTitle(from: cleaned).title
        var code = Self.extractMermaidTitle(from: cleaned).code
        let foundMatch = Self.findMermaidPattern(in: code, matchedCode: &code)

        if foundMatch {
            code = Self.fixMermaidKeywordSpacing(code)
        } else {
            if code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ""
            }
            code = "\(fallbackPrefix)\n  " + code.replacingOccurrences(of: "\n", with: "\n  ")
        }

        if code.trimmingCharacters(in: .whitespaces) == "graph" {
            code = ["graph", "TD"].joined(separator: " ")
        }

        code = sanitizeMermaidSyntax(code)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        // 若最终代码仅剩关键字（如 "mindmap" 或 "graph TD"），视为空无效图表
        if trimmedCode == "mindmap" || trimmedCode == "graph TD" || trimmedCode == "graph" {
            return ""
        }

        if let title = title {
            return "\(title)\n\n\(code)"
        }
        return code
    }

    /// 柔性自愈：将普通文本或 Markdown 节点转换为合法标准的 Mermaid Mindmap 代码
    /// - Parameters:
    ///   - text: LLM 返回的文本内容
    ///   - title: 根节点标题
    /// - Returns: 符合 Mermaid 规范的 Mindmap 代码
    static func convertMarkdownToListMindmap(_ text: String, title: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var mermaidLines = ["# \(title)", "", "mindmap", "  root((\(title)))"]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("```") || trimmed.lowercased() == "mindmap" { continue }
            let cleanText = trimmed.replacingOccurrences(of: "#", with: "")
                                   .replacingOccurrences(of: "-", with: "")
                                   .replacingOccurrences(of: "*", with: "")
                                   .trimmingCharacters(in: .whitespaces)
            if !cleanText.isEmpty && cleanText != title {
                mermaidLines.append("    \(cleanText)")
            }
        }
        if mermaidLines.count <= 4 {
            mermaidLines.append("    \(L10n.AI.Synthesis.Mindmap.title)")
        }
        return mermaidLines.joined(separator: "\n")
    }

    private static func cleanMermaidDelimiters(_ text: String) -> String {
        text.replacingOccurrences(of: "```mermaid", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractMermaidTitle(from cleaned: String) -> (title: String?, code: String) {
        guard cleaned.hasPrefix("# "),
              let firstLineEnd = cleaned.firstIndex(of: "\n") else { return (nil, cleaned) }
        let title = String(cleaned[..<firstLineEnd])
        let code = String(cleaned[cleaned.index(after: firstLineEnd)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, code)
    }

    private static func findMermaidPattern(in cleaned: String, matchedCode: inout String) -> Bool {
        let patterns = ["mindmap.*", "graph.*", "pie.*", "timeline.*", "sequenceDiagram.*", "gantt.*"]
        for pattern in patterns {
            if let range = cleaned.range(of: "(?s)\(pattern)", options: .regularExpression) {
                matchedCode = String(cleaned[range])
                return true
            }
        }
        return false
    }

    private static func fixMermaidKeywordSpacing(_ code: String) -> String {
        let keywords = ["mindmap", ["graph", "TD"].joined(separator: " "), ["graph", "LR"].joined(separator: " "), ["graph", "TB"].joined(separator: " "), ["graph", "BT"].joined(separator: " "), "graph", "timeline", "gantt", "pie", "sequenceDiagram"]
        for keyword in keywords where code.hasPrefix(keyword) {
            let afterKeyword = code.dropFirst(keyword.count)
            if !afterKeyword.isEmpty && !afterKeyword.hasPrefix("\n") {
                return keyword + "\n  " + afterKeyword.trimmingCharacters(in: .whitespaces)
            }
            break
        }
        return code
    }

    /// 对 Mermaid 进行语法纠错加固 (处理节点文本中的非法字符与缩进)
    private static func sanitizeMermaidSyntax(_ code: String) -> String {
        let isMindmap = code.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("mindmap")
        var lines = code.components(separatedBy: .newlines)

        for i in 0..<lines.count {
            var line = lines[i]
            // Tab 缩进归一化：将所有 Tab 替换为 2 个标准空格
            line = line.replacingOccurrences(of: "\t", with: "  ")
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed == "mindmap" || trimmed == "graph TD" {
                lines[i] = line
                continue
            }

            // 获取缩进
            let indentation = line.prefix { $0.isWhitespace }

            if isMindmap {
                // 针对 mindmap 的特殊处理：
                // 1. 移除行尾可能导致解析错误的连字符
                var content = trimmed.replacingOccurrences(of: #"-+$"#, with: "", options: .regularExpression)

                // 2. 如果包含冒号、括号等特殊字符且未加双引号，套上双引号
                let hasBrackets = (content.contains("((") && content.contains("))")) ||
                                  (content.contains("[") && content.contains("]")) ||
                                  (content.contains("{{") && content.contains("}}")) ||
                                  (content.contains("(") && content.contains(")"))

                let hasSpecialChars = content.contains(":") || content.contains("?") || content.contains("_")

                if (!hasBrackets || hasSpecialChars) && !content.hasPrefix("\"") {
                    let safeText = content.replacingOccurrences(of: "\"", with: "'")
                    content = "\"\(safeText)\""
                }

                line = String(indentation) + content
            } else {
                // 针对 graph 等其他图表的通用处理
                let pattern = #"(\w+)(\[+|\(+|\{+)(.+?)(\]+|\)+|\}+)"#
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(location: 0, length: line.utf16.count)
                    line = regex.stringByReplacingMatches(in: line, options: [], range: range, withTemplate: #"$1["$3"]"#)
                }

                // 标签内容净化
                if let start = line.firstIndex(of: "["), let end = line.lastIndex(of: "]") {
                    let range = line.index(after: start)..<end
                    let inner = line[range]
                    var innerText = String(inner)
                    if innerText.hasPrefix("\"") && innerText.hasSuffix("\"") {
                        innerText = String(innerText.dropFirst().dropLast())
                    }

                    let cleaned = innerText.replacingOccurrences(of: "\"", with: "'")
                                           .trimmingCharacters(in: .whitespaces)
                    line.replaceSubrange(range, with: "\"\(cleaned)\"")
                }
            }

            lines[i] = line
        }
        return lines.joined(separator: "\n")
    }

    /// 从文本内容中提取第一个 H1 级别的标题
    static func extractTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // 寻找第一个非空的 Markdown 标题行
        if let firstLine = lines.first(where: { !$0.isEmpty && $0.hasPrefix("# ") }) {
            return firstLine.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: .whitespaces)
        }

        return nil
    }

    /// 清理 Markdown 内容中的冗余转义（如 \+ -> +）
    static func cleanMarkdown(_ text: String) -> String {
        var cleaned = text
        // 移除常见的冗余转义字符，LLM 经常在列表中或 Knowledge links 中转义这些字符
        let replacements = [
            "\\+": "+",
            "\\-": "-",
            "\\*": "*",
            "\\. ": ". ",
            "\\!": "!",
            "\\[\\[": "[[",
            "\\]\\]": "]]",
            "\\\\[": "[",
            "\\\\]": "]"
        ]

        for (target, replacement) in replacements {
            cleaned = cleaned.replacingOccurrences(of: target, with: replacement)
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

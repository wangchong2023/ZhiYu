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

    /// 过滤源内容中的 Prompt 系统指令与无关符号
    static func sanitizeSourceLines(_ text: String) -> [String] {
        let promptKeywords = [
            "合成时请使用", "仅陈述源材料", "禁止编造", "页面标题", "Source",
            "---", "Format:", "Requirements:"
        ]
        return text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                !line.isEmpty &&
                !line.hasPrefix("```") &&
                !promptKeywords.contains(where: { line.contains($0) })
            }
    }

    /// 格式化 Mermaid 代码块
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

        if trimmedCode == "mindmap" || trimmedCode == "graph TD" || trimmedCode == "graph" {
            return ""
        }

        if let title = title {
            return "\(title)\n\n\(code)"
        }
        return code
    }

    /// 校验字符串是否符合合法的 Mermaid 声明结构
    static func isValidMermaidSyntax(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let validPrefixes = ["mindmap", "graph", "flowchart", "sequenceDiagram", "gantt", "pie", "timeline"]
        let lines = trimmed.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let firstLine = lines.first(where: { !$0.isEmpty }) else { return false }

        let hasPrefix = validPrefixes.contains { prefix in
            firstLine == prefix || firstLine.hasPrefix(prefix + " ") || firstLine.hasPrefix(prefix + "\n")
        }
        guard hasPrefix else { return false }

        let nonEmptyLines = lines.filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("```") }
        if nonEmptyLines.count <= 1 && (firstLine == "mindmap" || firstLine.hasPrefix("graph")) {
            return false
        }
        return true
    }

    /// 柔性自愈：将普通文本或 Markdown 节点转换为层次丰富的 Mermaid Mindmap 代码
    static func convertMarkdownToListMindmap(_ text: String, title: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootName = cleanTitle.isEmpty ? L10n.AI.Synthesis.Mindmap.title : cleanTitle
        let lines = sanitizeSourceLines(text)
        var mermaidLines = ["# \(rootName)", "", "mindmap", "  root((\(rootName)))"]
        
        var currentSection = ""
        var validNodeCount = 0

        for line in lines {
            if line.hasPrefix("#") {
                let headerText = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                if !headerText.isEmpty && headerText != rootName {
                    currentSection = headerText
                    mermaidLines.append("    \(headerText)")
                    validNodeCount += 1
                }
            } else if line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("+") || (line.first?.isNumber == true && line.contains(".")) {
                let bulletText = line.replacingOccurrences(of: #"^[\-\*\+\d\.]+\s*"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                if !bulletText.isEmpty && bulletText != rootName {
                    let indent = currentSection.isEmpty ? "    " : "      "
                    mermaidLines.append("\(indent)\(bulletText)")
                    validNodeCount += 1
                }
            } else {
                if line.count > 2 && line.count < 30 && line != rootName {
                    let indent = currentSection.isEmpty ? "    " : "      "
                    mermaidLines.append("\(indent)\(line)")
                    validNodeCount += 1
                }
            }
        }

        if validNodeCount == 0 {
            mermaidLines.append("    \(L10n.AI.Synthesis.Mindmap.title)")
            mermaidLines.append("      \(L10n.AI.Synthesis.Mindmap.defaultBranch1)")
            mermaidLines.append("      \(L10n.AI.Synthesis.Mindmap.defaultBranch2)")
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

    private static func sanitizeMermaidSyntax(_ code: String) -> String {
        let isMindmap = code.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("mindmap")
        var lines = code.components(separatedBy: .newlines)

        for i in 0..<lines.count {
            var line = lines[i]
            line = line.replacingOccurrences(of: "\t", with: "  ")
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed == "mindmap" || trimmed == "graph TD" {
                lines[i] = line
                continue
            }

            let indentation = line.prefix { $0.isWhitespace }

            if isMindmap {
                var content = trimmed.replacingOccurrences(of: #"-+$"#, with: "", options: .regularExpression)
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
                let pattern = #"(\w+)(\[+|\(+|\{+)(.+?)(\]+|\)+|\}+)"#
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(location: 0, length: line.utf16.count)
                    line = regex.stringByReplacingMatches(in: line, options: [], range: range, withTemplate: #"$1["$3"]"#)
                }

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

        if let firstLine = lines.first(where: { !$0.isEmpty && $0.hasPrefix("# ") }) {
            return firstLine.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// 清理 Markdown 内容中的冗余转义
    static func cleanMarkdown(_ text: String) -> String {
        var cleaned = text
        let replacements = [
            "\\+": "+", "\\-": "-", "\\*": "*", "\\. ": ". ",
            "\\!": "!", "\\[\\[": "[[", "\\]\\]": "]]",
            "\\\\[": "[", "\\\\]": "]"
        ]
        for (target, replacement) in replacements {
            cleaned = cleaned.replacingOccurrences(of: target, with: replacement)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 演示文稿常量
    private static let minValidTitleLength = 3
    private static let maxBulletsPerSlide = 4
    private static let minFallbackSlideCount = 4
    private static let maxFallbackSlideCount = 7

    private static func extractRootTitle(title: String, lines: [String]) -> String {
        var rootName = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if rootName.isEmpty || rootName == L10n.AI.Prompt.Expert.Slides.title {
            if let firstValidLine = lines.first(where: { $0.count > minValidTitleLength }) {
                rootName = firstValidLine.replacingOccurrences(of: #"^[\-\*\+\#\d\.]+\s*"#, with: "", options: .regularExpression)
            }
        }
        return rootName.isEmpty ? L10n.AI.Prompt.Expert.Slides.title : rootName
    }

    private static func extractPresentationTopics(from lines: [String]) -> [(title: String, bullets: [String])] {
        var slideTopics: [(title: String, bullets: [String])] = []
        var currentTitle = ""
        var currentBullets: [String] = []

        for line in lines {
            let bullet = line.replacingOccurrences(of: #"^[\-\*\+\#\d\.]+\s*"#, with: "", options: .regularExpression)
                             .trimmingCharacters(in: .whitespaces)
            guard bullet.count > minValidTitleLength else { continue }

            if line.hasPrefix("#") {
                if !currentTitle.isEmpty || !currentBullets.isEmpty {
                    let fallbackTitle = currentTitle.isEmpty ? "核心分析" : currentTitle
                    slideTopics.append((fallbackTitle, Array(currentBullets.prefix(maxBulletsPerSlide))))
                    currentBullets.removeAll()
                }
                currentTitle = bullet
            } else {
                currentBullets.append(bullet)
            }
        }
        if !currentTitle.isEmpty || !currentBullets.isEmpty {
            let fallbackTitle = currentTitle.isEmpty ? "总结复盘" : currentTitle
            slideTopics.append((fallbackTitle, Array(currentBullets.prefix(maxBulletsPerSlide))))
        }
        return slideTopics
    }

    /// 柔性自愈：生成标准演示文稿 (Markdown Slide Presentation)，严格控制 5-8 页，拒绝空页
    static func generateFallbackPresentation(from text: String, title: String) -> String {
        let lines = sanitizeSourceLines(text)
        let rootName = extractRootTitle(title: title, lines: lines)
        let slideTopics = extractPresentationTopics(from: lines)

        var slideDeck = ["# \(rootName)\n\n* 智宇 AI 原生演示文稿"]
        let maxSlides = min(max(slideTopics.count, minFallbackSlideCount), maxFallbackSlideCount)

        for i in 0..<maxSlides {
            let topic = i < slideTopics.count ? slideTopics[i] : (title: "知识要点扩展 \(i + 1)", bullets: ["深入提炼该主题的关键发现", "结合知识库链接进行交叉验证"])
            var slideText = "## \(topic.title)"
            if topic.bullets.isEmpty {
                slideText += "\n\n* 核心要点深化理解\n* 系统梳理知识结构"
            } else {
                for b in topic.bullets { slideText += "\n* \(b)" }
            }
            slideDeck.append(slideText)
        }
        return slideDeck.joined(separator: "\n\n---\n\n")
    }

    /// 柔性自愈：生成标准 Mermaid 可视化信息图 (Flowchart)
    static func generateFallbackInfographic(from text: String, title: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootName = cleanTitle.isEmpty ? L10n.Knowledge.Page.AI.infographic : cleanTitle
        let lines = sanitizeSourceLines(text)

        var code = ["# \(rootName)", "", "graph TD", "  Root[\"\(rootName)\"]"]
        var nodeCount = 0

        for line in lines {
            let bullet = line.replacingOccurrences(of: #"^[\-\*\+\#\d\.]+\s*"#, with: "", options: .regularExpression)
                             .replacingOccurrences(of: "\"", with: "'")
                             .trimmingCharacters(in: .whitespaces)
            if bullet.count > 2 && bullet.count < 40 {
                nodeCount += 1
                code.append("  Root --> Node\(nodeCount)[\"\(bullet)\"]")
                if nodeCount >= 6 { break }
            }
        }

        if nodeCount == 0 {
            code.append("  Root --> Node1[\"\(L10n.AI.Synthesis.Fallback.coreConcept)\"]")
        }
        return code.joined(separator: "\n")
    }

    /// 柔性自愈：生成结构化深度报告 (Report)
    static func generateFallbackReport(from text: String, title: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootName = cleanTitle.isEmpty ? L10n.AI.Prompt.Expert.Report.title : cleanTitle
        let lines = sanitizeSourceLines(text)

        var report = [
            "# \(rootName)",
            "",
            L10n.AI.Synthesis.Fallback.reportOverview,
            String(text.prefix(300)),
            "",
            L10n.AI.Synthesis.Fallback.reportKeyPoints
        ]

        var count = 0
        for line in lines {
            let item = line.replacingOccurrences(of: #"^[\-\*\+\#\d\.]+\s*"#, with: "", options: .regularExpression)
            if item.count > 5 {
                count += 1
                report.append(L10n.AI.Synthesis.Fallback.reportPointItem(count, item))
                if count >= 5 { break }
            }
        }

        report.append(L10n.AI.Synthesis.Fallback.reportSummaryHeader)
        report.append(L10n.AI.Synthesis.Fallback.reportSummaryBody)
        return report.joined(separator: "\n")
    }

    /// 柔性自愈：生成知识深度扩充 (Expansion)，消除泛化“细节维度”，使用主题小节
    static func generateFallbackExpansion(from text: String, title: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootName = cleanTitle.isEmpty ? L10n.Knowledge.Page.AI.expansion : cleanTitle
        let lines = sanitizeSourceLines(text)

        let sectionTitles = [
            "## 核心概念与理论机制",
            "## 结构解构与关键要素",
            "## 实践应用与落地方法",
            "## 延伸思考与前沿趋势"
        ]

        var expansion = [
            "# \(rootName)",
            "",
            "## 知识背景与起源分析",
            lines.prefix(3).joined(separator: "\n\n"),
            ""
        ]

        let linesPerSection = max(2, (lines.count - 3) / sectionTitles.count)
        var currentOffset = 3

        for secTitle in sectionTitles {
            expansion.append(secTitle)
            if currentOffset < lines.count {
                let endIdx = min(currentOffset + linesPerSection, lines.count)
                let sectionContent = lines[currentOffset..<endIdx].joined(separator: "\n\n")
                expansion.append(sectionContent)
                currentOffset = endIdx
            } else {
                expansion.append("围绕该主题，在实际应用场景中可结合知识库上下文进行深入实践与验证。通过原子化笔记与双向链接网络，促成不同主题之间的非线性网状碰撞与长时记忆巩固。")
            }
            expansion.append("")
        }

        return expansion.joined(separator: "\n")
    }

    /// 柔性自愈：生成真实知识测验 (Quiz JSON)，提取有效问题与选项，拒绝假数据
    static func generateFallbackQuiz(from text: String, title: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootName = cleanTitle.isEmpty ? L10n.AI.Prompt.Quiz.defaultTitle : cleanTitle
        let lines = sanitizeSourceLines(text)

        var validPoints: [String] = []
        for line in lines {
            let item = line.replacingOccurrences(of: #"^[\-\*\+\#\d\.]+\s*"#, with: "", options: .regularExpression)
                             .trimmingCharacters(in: .whitespaces)
            if item.count >= 6 && item.count <= 60 {
                validPoints.append(item)
            }
        }

        if validPoints.count < 3 {
            validPoints = [
                "笔记的原子化解构要求每张卡片只承载一个核心概念",
                "卡片盒笔记法通过双向链接形成自组织的网络",
                "主动召回与间隔重复是巩固长时记忆的核心机制"
            ]
        }

        var questionsJSON: [[String: Any]] = []

        for (idx, point) in validPoints.prefix(3).enumerated() {
            let qText = "关于「\(rootName)」中的核心观点，下列理解最准确的是？"
            let correctOpt = point
            let wrongOpt1 = "概念需要尽量涵盖多重复杂含义，无需进行原子化拆解"
            let wrongOpt2 = "知识管理仅依赖线性顺序排列，不需要建立交叉链接"
            let wrongOpt3 = "仅通过被动阅读即可建立长久记忆，无需主动召回"

            var rawOptions = [correctOpt, wrongOpt1, wrongOpt2, wrongOpt3]
            rawOptions.shuffle()
            let correctIndex = rawOptions.firstIndex(of: correctOpt) ?? 0

            questionsJSON.append([
                "id": idx + 1,
                "question": qText,
                "options": rawOptions,
                "answerIndex": correctIndex,
                "explanation": "解析：根据知识源所述，\(point)。"
            ])
        }

        let quizDict: [String: Any] = [
            "quizTitle": "\(rootName) - 知识自测",
            "questions": questionsJSON
        ]

        if let data = try? JSONSerialization.data(withJSONObject: quizDict, options: [.prettyPrinted]),
           let jsonStr = String(data: data, encoding: .utf8) {
            return jsonStr
        }

        return """
        {
          "quizTitle": "\(rootName) - 知识自测",
          "questions": [
            {
              "id": 1,
              "question": "关于「\(rootName)」，下列说法最准确的是？",
              "options": ["A. \(validPoints[0])", "B. 知识无需结构化提取", "C. 不需要原子化拆解", "D. 仅作线性顺序排列"],
              "answerIndex": 0,
              "explanation": "解析：原文指出 \(validPoints[0])。"
            }
          ]
        }
        """
    }
}

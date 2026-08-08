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
        let promptKeywords = ProcessorConstants.Synthesis.promptKeywords + [
            L10n.AI.Synthesis.Control.depth,
            L10n.AI.Synthesis.Control.audience,
            L10n.AI.Synthesis.Control.tone
        ]
        return text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                !line.isEmpty &&
                !line.hasPrefix(ProcessorConstants.MarkdownSyntax.codeFence) &&
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
            code = "\(fallbackPrefix)\(ProcessorConstants.Whitespace.newlineWithIndent)" + code.replacingOccurrences(of: ProcessorConstants.Whitespace.newline, with: ProcessorConstants.Whitespace.newlineWithIndent)
        }

        if code.trimmingCharacters(in: .whitespaces) == ProcessorConstants.MermaidSyntax.graph {
            code = [ProcessorConstants.MermaidSyntax.graph, ProcessorConstants.MermaidSyntax.td].joined(separator: ProcessorConstants.Whitespace.space)
        }

        code = sanitizeMermaidSyntax(code)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedCode == ProcessorConstants.MermaidSyntax.mindmap || trimmedCode == ProcessorConstants.MermaidSyntax.graphTD || trimmedCode == ProcessorConstants.MermaidSyntax.graph {
            return ""
        }

        if let title = title {
            return "\(title)\(ProcessorConstants.Whitespace.doubleNewline)\(code)"
        }
        return code
    }

    /// 校验字符串是否符合合法的 Mermaid 声明结构
    static func isValidMermaidSyntax(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let validPrefixes = ProcessorConstants.MermaidSyntax.validPrefixes
        let lines = trimmed.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let firstLine = lines.first(where: { !$0.isEmpty }) else { return false }

        let hasPrefix = validPrefixes.contains { prefix in
            firstLine == prefix || firstLine.hasPrefix(prefix + ProcessorConstants.Whitespace.space) || firstLine.hasPrefix(prefix + ProcessorConstants.Whitespace.newline)
        }
        guard hasPrefix else { return false }

        let nonEmptyLines = lines.filter { !$0.isEmpty && !$0.hasPrefix(ProcessorConstants.MarkdownSyntax.hash) && !$0.hasPrefix(ProcessorConstants.MarkdownSyntax.codeFence) }
        if nonEmptyLines.count <= 1 && (firstLine == ProcessorConstants.MermaidSyntax.mindmap || firstLine.hasPrefix(ProcessorConstants.MermaidSyntax.graph)) {
            return false
        }
        return true
    }

    /// 柔性自愈：将普通文本或 Markdown 节点转换为层次丰富的 Mermaid Mindmap 代码
    static func convertMarkdownToListMindmap(_ text: String, title: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootName = cleanTitle.isEmpty ? L10n.AI.Synthesis.Mindmap.title : cleanTitle
        let lines = sanitizeSourceLines(text)
        var mermaidLines = [
            "\(ProcessorConstants.MarkdownSyntax.h1Prefix)\(rootName)",
            ProcessorConstants.Whitespace.empty,
            ProcessorConstants.MermaidSyntax.mindmap,
            "\(ProcessorConstants.Synthesis.mermaidIndentLevel2)\(ProcessorConstants.MermaidSyntax.mindmapRoot)\(ProcessorConstants.MermaidSyntax.doubleParenOpen)\(rootName)\(ProcessorConstants.MermaidSyntax.doubleParenClose)"
        ]

        var currentSection = ""
        var validNodeCount = 0

        for line in lines {
            if line.hasPrefix(ProcessorConstants.MarkdownSyntax.hash) {
                let headerText = line.replacingOccurrences(of: ProcessorConstants.MarkdownSyntax.hash, with: "").trimmingCharacters(in: .whitespaces)
                if !headerText.isEmpty && headerText != rootName {
                    currentSection = headerText
                    mermaidLines.append("\(ProcessorConstants.Synthesis.mermaidIndentLevel1)\(headerText)")
                    validNodeCount += 1
                }
            } else if line.hasPrefix(ProcessorConstants.MarkdownSyntax.bulletDash) || line.hasPrefix(ProcessorConstants.MarkdownSyntax.bulletAsterisk) || line.hasPrefix(ProcessorConstants.MarkdownSyntax.bulletPlus) || (line.first?.isNumber == true && line.contains(ProcessorConstants.MarkdownSyntax.dot)) {
                let bulletText = line.replacingOccurrences(of: ProcessorConstants.RegexPattern.markdownBulletStrip, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                if !bulletText.isEmpty && bulletText != rootName {
                    let indent = currentSection.isEmpty ? ProcessorConstants.Synthesis.mermaidIndentLevel1 : ProcessorConstants.Synthesis.mermaidIndentLevel2
                    mermaidLines.append("\(indent)\(bulletText)")
                    validNodeCount += 1
                }
            } else {
                if line.count > ProcessorConstants.Synthesis.mindmapNodeMinLength && line.count < ProcessorConstants.Synthesis.mindmapNodeMaxLength && line != rootName {
                    let indent = currentSection.isEmpty ? ProcessorConstants.Synthesis.mermaidIndentLevel1 : ProcessorConstants.Synthesis.mermaidIndentLevel2
                    mermaidLines.append("\(indent)\(line)")
                    validNodeCount += 1
                }
            }
        }

        if validNodeCount == 0 {
            mermaidLines.append("\(ProcessorConstants.Synthesis.mermaidIndentLevel1)\(L10n.AI.Synthesis.Mindmap.title)")
            mermaidLines.append("\(ProcessorConstants.Synthesis.mermaidIndentLevel2)\(L10n.AI.Synthesis.Mindmap.defaultBranch1)")
            mermaidLines.append("\(ProcessorConstants.Synthesis.mermaidIndentLevel2)\(L10n.AI.Synthesis.Mindmap.defaultBranch2)")
        }

        return mermaidLines.joined(separator: ProcessorConstants.Whitespace.newline)
    }

    private static func cleanMermaidDelimiters(_ text: String) -> String {
        text.replacingOccurrences(of: ProcessorConstants.MarkdownSyntax.mermaidFence, with: ProcessorConstants.Whitespace.empty)
            .replacingOccurrences(of: ProcessorConstants.MarkdownSyntax.codeFence, with: ProcessorConstants.Whitespace.empty)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractMermaidTitle(from cleaned: String) -> (title: String?, code: String) {
        guard cleaned.hasPrefix(ProcessorConstants.MarkdownSyntax.h1Prefix),
              let firstLineEnd = cleaned.firstIndex(of: Character(ProcessorConstants.Whitespace.newline)) else { return (nil, cleaned) }
        let title = String(cleaned[..<firstLineEnd])
        let code = String(cleaned[cleaned.index(after: firstLineEnd)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, code)
    }

    private static func findMermaidPattern(in cleaned: String, matchedCode: inout String) -> Bool {
        let patterns = ProcessorConstants.MermaidSyntax.matchPatterns
        for pattern in patterns {
            if let range = cleaned.range(of: "\(ProcessorConstants.RegexPattern.multilineFlag)\(pattern)", options: .regularExpression) {
                matchedCode = String(cleaned[range])
                return true
            }
        }
        return false
    }

    private static func fixMermaidKeywordSpacing(_ code: String) -> String {
        let keywords = ProcessorConstants.MermaidSyntax.keywordSpacingCandidates
        for keyword in keywords where code.hasPrefix(keyword) {
            let afterKeyword = code.dropFirst(keyword.count)
            if !afterKeyword.isEmpty && !afterKeyword.hasPrefix(ProcessorConstants.Whitespace.newline) {
                return keyword + ProcessorConstants.Whitespace.newlineWithIndent + afterKeyword.trimmingCharacters(in: .whitespaces)
            }
            break
        }
        return code
    }

    private static func sanitizeMermaidSyntax(_ code: String) -> String {
        let isMindmap = code.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(ProcessorConstants.MermaidSyntax.mindmap)
        var lines = code.components(separatedBy: .newlines)

        for i in 0..<lines.count {
            var line = lines[i]
            line = line.replacingOccurrences(of: ProcessorConstants.Whitespace.tab, with: ProcessorConstants.Whitespace.doubleSpace)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed == ProcessorConstants.MermaidSyntax.mindmap || trimmed == ProcessorConstants.MermaidSyntax.graphTD {
                lines[i] = line
                continue
            }

            let indentation = line.prefix { $0.isWhitespace }

            if isMindmap {
                var content = trimmed.replacingOccurrences(of: ProcessorConstants.RegexPattern.mermaidTrailingDash, with: "", options: .regularExpression)
                let hasBrackets = (content.contains(ProcessorConstants.MermaidSyntax.doubleParenOpen) && content.contains(ProcessorConstants.MermaidSyntax.doubleParenClose)) ||
                                  (content.contains(ProcessorConstants.MarkdownSyntax.openBracket) && content.contains(ProcessorConstants.MarkdownSyntax.closeBracket)) ||
                                  (content.contains(ProcessorConstants.MermaidSyntax.doubleBraceOpen) && content.contains(ProcessorConstants.MermaidSyntax.doubleBraceClose)) ||
                                  (content.contains(ProcessorConstants.MarkdownSyntax.openParen) && content.contains(ProcessorConstants.MarkdownSyntax.closeParen))
                let hasSpecialChars = content.contains(ProcessorConstants.MarkdownSyntax.colon) || content.contains(ProcessorConstants.MarkdownSyntax.questionMark) || content.contains(ProcessorConstants.MarkdownSyntax.underscore)

                if (!hasBrackets || hasSpecialChars) && !content.hasPrefix(ProcessorConstants.MarkdownSyntax.doubleQuote) {
                    let safeText = content.replacingOccurrences(of: ProcessorConstants.MarkdownSyntax.doubleQuote, with: ProcessorConstants.MarkdownSyntax.singleQuote)
                    content = "\(ProcessorConstants.MarkdownSyntax.doubleQuote)\(safeText)\(ProcessorConstants.MarkdownSyntax.doubleQuote)"
                }
                line = String(indentation) + content
            } else {
                let pattern = ProcessorConstants.RegexPattern.mermaidNodeBracket
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(location: 0, length: line.utf16.count)
                    line = regex.stringByReplacingMatches(in: line, options: [], range: range, withTemplate: ProcessorConstants.RegexPattern.mermaidNodeTemplate)
                }

                if let start = line.firstIndex(of: Character(ProcessorConstants.MarkdownSyntax.openBracket)), let end = line.lastIndex(of: Character(ProcessorConstants.MarkdownSyntax.closeBracket)) {
                    let range = line.index(after: start)..<end
                    let inner = line[range]
                    var innerText = String(inner)
                    if innerText.hasPrefix(ProcessorConstants.MarkdownSyntax.doubleQuote) && innerText.hasSuffix(ProcessorConstants.MarkdownSyntax.doubleQuote) {
                        innerText = String(innerText.dropFirst().dropLast())
                    }
                    let cleaned = innerText.replacingOccurrences(of: ProcessorConstants.MarkdownSyntax.doubleQuote, with: ProcessorConstants.MarkdownSyntax.singleQuote)
                                           .trimmingCharacters(in: .whitespaces)
                    line.replaceSubrange(range, with: "\(ProcessorConstants.MarkdownSyntax.doubleQuote)\(cleaned)\(ProcessorConstants.MarkdownSyntax.doubleQuote)")
                }
            }
            lines[i] = line
        }
        return lines.joined(separator: ProcessorConstants.Whitespace.newline)
    }

    /// 拦截并对 Mermaid 节点文本中的危险字符（冒号、问号、括号、下划线、花括号等）进行前置转义包覆处理，防止渲染语法解析崩溃
    static func safeMermaidSyntax(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ProcessorConstants.Whitespace.empty }

        let dangerChars = ProcessorConstants.Synthesis.mermaidDangerChars
        let needsQuoting = dangerChars.contains(where: { trimmed.contains($0) })

        if needsQuoting && !(trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.doubleQuote) && trimmed.hasSuffix(ProcessorConstants.MarkdownSyntax.doubleQuote)) {
            let safeContent = trimmed.replacingOccurrences(of: ProcessorConstants.MarkdownSyntax.doubleQuote, with: ProcessorConstants.MarkdownSyntax.singleQuote)
            return "\(ProcessorConstants.MarkdownSyntax.doubleQuote)\(safeContent)\(ProcessorConstants.MarkdownSyntax.doubleQuote)"
        }
        return trimmed
    }

    /// 从文本内容中提取第一个 H1 级别的合法标题（过滤 Prompt 指令标头）
    static func extractTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        for line in lines where !line.isEmpty {
            if line.hasPrefix(ProcessorConstants.MarkdownSyntax.h1Prefix) {
                let candidate = line.replacingOccurrences(of: ProcessorConstants.RegexPattern.markdownHeaderStrip, with: "", options: .regularExpression)
                                    .replacingOccurrences(of: ProcessorConstants.MarkdownSyntax.codeFence, with: ProcessorConstants.Whitespace.empty)
                                    .trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty &&
                    !candidate.hasPrefix(ProcessorConstants.MarkdownSyntax.cjkOpenBracket) &&
                    !candidate.contains(L10n.AI.Synthesis.Control.depth) &&
                    !candidate.contains(L10n.AI.Synthesis.Control.audience) &&
                    !candidate.contains(L10n.AI.Synthesis.Control.tone) {
                    return candidate
                }
            }
        }
        return nil
    }

    /// 清理 Markdown 内容中的冗余转义与裸露 Prompt 控制参数
    static func cleanMarkdown(_ text: String) -> String {
        var cleaned = text
        let promptPatterns = [
            ProcessorConstants.RegexPattern.promptBlockDepth,
            ProcessorConstants.RegexPattern.promptBlockShort
        ]
        for pat in promptPatterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: []) {
                let range = NSRange(location: 0, length: cleaned.utf16.count)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
            }
        }

        let replacements = ProcessorConstants.MarkdownSyntax.escapeReplacements
        for (target, replacement) in replacements {
            cleaned = cleaned.replacingOccurrences(of: target, with: replacement)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractRootTitle(title: String, lines: [String]) -> String {
        var rootName = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if rootName.hasPrefix(ProcessorConstants.MarkdownSyntax.cjkOpenBracket) || rootName.contains(L10n.AI.Synthesis.Control.depth) || rootName.contains(L10n.AI.Synthesis.Control.audience) {
            rootName = ""
        }
        if rootName.isEmpty || rootName == L10n.AI.Prompt.Expert.Slides.title {
            if let firstValidLine = lines.first(where: {
                $0.count > ProcessorConstants.Synthesis.minValidTitleLength &&
                !$0.hasPrefix(ProcessorConstants.MarkdownSyntax.cjkOpenBracket) &&
                !$0.contains(L10n.AI.Synthesis.Control.depth) &&
                !$0.contains(L10n.AI.Synthesis.Control.audience)
            }) {
                rootName = firstValidLine.replacingOccurrences(of: ProcessorConstants.RegexPattern.markdownBulletStrip, with: "", options: .regularExpression)
            }
        }
        return rootName.isEmpty ? L10n.AI.Prompt.Expert.Slides.title : rootName
    }

    private static func extractPresentationTopics(from lines: [String]) -> [(title: String, bullets: [String])] {
        var slideTopics: [(title: String, bullets: [String])] = []
        var currentTitle = ""
        var currentBullets: [String] = []

        for line in lines {
            let bullet = line.replacingOccurrences(of: ProcessorConstants.RegexPattern.markdownBulletStrip, with: "", options: .regularExpression)
                             .trimmingCharacters(in: .whitespaces)
            guard bullet.count > ProcessorConstants.Synthesis.minValidTitleLength else { continue }

            if line.hasPrefix(ProcessorConstants.MarkdownSyntax.hash) {
                if !currentTitle.isEmpty || !currentBullets.isEmpty {
                    let fallbackTitle = currentTitle.isEmpty ? L10n.AI.Synthesis.Fallback.coreAnalysis : currentTitle
                    slideTopics.append((fallbackTitle, Array(currentBullets.prefix(ProcessorConstants.Synthesis.maxBulletsPerSlide))))
                    currentBullets.removeAll()
                }
                currentTitle = bullet
            } else {
                currentBullets.append(bullet)
            }
        }
        if !currentTitle.isEmpty || !currentBullets.isEmpty {
            let fallbackTitle = currentTitle.isEmpty ? L10n.AI.Synthesis.Fallback.summaryReview : currentTitle
            slideTopics.append((fallbackTitle, Array(currentBullets.prefix(ProcessorConstants.Synthesis.maxBulletsPerSlide))))
        }
        return slideTopics
    }

    /// 柔性自愈：如果演示文稿缺乏 --- 分页符，自动根据标题层级将文本切割组装为 Slides
    static func formatSlidesIfNeeded(_ text: String, fallbackTitle: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(ProcessorConstants.MarkdownSyntax.slideSeparator) || trimmed.contains(ProcessorConstants.MarkdownSyntax.slideSeparatorSpaced) {
            return trimmed
        }
        let lines = sanitizeSourceLines(trimmed)
        let rootName = extractRootTitle(title: fallbackTitle, lines: lines)
        let slideTopics = extractPresentationTopics(from: lines)
        if slideTopics.isEmpty {
            return generateFallbackPresentation(from: trimmed, title: fallbackTitle)
        }

        var slideDeck = ["\(ProcessorConstants.MarkdownSyntax.h1Prefix)\(rootName)\(ProcessorConstants.Whitespace.doubleNewline)\(ProcessorConstants.MarkdownSyntax.bulletAsterisk)\(L10n.AI.Prompt.Expert.Slides.title)"]
        for topic in slideTopics {
            var slideText = "\(ProcessorConstants.MarkdownSyntax.h2Prefix)\(topic.title)"
            for bullet in topic.bullets {
                slideText += "\(ProcessorConstants.Whitespace.newline)\(ProcessorConstants.MarkdownSyntax.bulletAsterisk)\(bullet)"
            }
            slideDeck.append(slideText)
        }
        return slideDeck.joined(separator: ProcessorConstants.MarkdownSyntax.slideJoinSeparator)
    }

    /// 柔性自愈：生成标准演示文稿 (Markdown Slide Presentation)，严格控制 5-8 页，拒绝空页
    static func generateFallbackPresentation(from text: String, title: String) -> String {
        let lines = sanitizeSourceLines(text)
        let rootName = extractRootTitle(title: title, lines: lines)
        let slideTopics = extractPresentationTopics(from: lines)

        var slideDeck = ["\(ProcessorConstants.MarkdownSyntax.h1Prefix)\(rootName)\(ProcessorConstants.Whitespace.doubleNewline)\(ProcessorConstants.MarkdownSyntax.bulletAsterisk)\(L10n.AI.Synthesis.Fallback.slidesSubtitle)"]
        let maxSlides = min(max(slideTopics.count, ProcessorConstants.Synthesis.minFallbackSlideCount), ProcessorConstants.Synthesis.maxFallbackSlideCount)

        for i in 0..<maxSlides {
            let topic = i < slideTopics.count ? slideTopics[i] : (title: L10n.AI.Synthesis.Fallback.expansionPointTitle(i + 1), bullets: [L10n.AI.Synthesis.Fallback.expansionBullet1, L10n.AI.Synthesis.Fallback.expansionBullet2])
            var slideText = "\(ProcessorConstants.MarkdownSyntax.h2Prefix)\(topic.title)"
            if topic.bullets.isEmpty {
                slideText += "\(ProcessorConstants.Whitespace.doubleNewline)\(ProcessorConstants.MarkdownSyntax.bulletAsterisk)\(L10n.AI.Synthesis.Fallback.slideBullet1)\(ProcessorConstants.Whitespace.newline)\(ProcessorConstants.MarkdownSyntax.bulletAsterisk)\(L10n.AI.Synthesis.Fallback.slideBullet2)"
            } else {
                for b in topic.bullets { slideText += "\(ProcessorConstants.Whitespace.newline)\(ProcessorConstants.MarkdownSyntax.bulletAsterisk)\(b)" }
            }
            slideDeck.append(slideText)
        }
        return slideDeck.joined(separator: ProcessorConstants.MarkdownSyntax.slideJoinSeparator)
    }

    /// 柔性自愈：生成标准 Mermaid 可视化信息图 (Flowchart)
    static func generateFallbackInfographic(from text: String, title: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootName = cleanTitle.isEmpty ? L10n.Knowledge.Page.AI.infographic : cleanTitle
        let lines = sanitizeSourceLines(text)

        var code = ["\(ProcessorConstants.MarkdownSyntax.h1Prefix)\(rootName)", ProcessorConstants.Whitespace.empty, ProcessorConstants.MermaidSyntax.graphTD, "\(ProcessorConstants.MermaidSyntax.indent)\(ProcessorConstants.MermaidSyntax.rootLabel)\(rootName)\(ProcessorConstants.MermaidSyntax.labelSuffix)"]
        var nodeCount = 0

        for line in lines {
            let bullet = line.replacingOccurrences(of: ProcessorConstants.RegexPattern.markdownBulletStrip, with: "", options: .regularExpression)
                             .replacingOccurrences(of: ProcessorConstants.MarkdownSyntax.doubleQuote, with: ProcessorConstants.MarkdownSyntax.singleQuote)
                             .trimmingCharacters(in: .whitespaces)
            if bullet.count > ProcessorConstants.Synthesis.infographicMinLength && bullet.count < ProcessorConstants.Synthesis.infographicMaxLength {
                nodeCount += 1
                code.append("\(ProcessorConstants.MermaidSyntax.indent)\(ProcessorConstants.MermaidSyntax.root)\(ProcessorConstants.MermaidSyntax.arrow)\(ProcessorConstants.MermaidSyntax.nodeLabel)\(nodeCount)[\"\(bullet)\"]")
                if nodeCount >= ProcessorConstants.Synthesis.infographicMaxNodes { break }
            }
        }

        if nodeCount == 0 {
            code.append("\(ProcessorConstants.MermaidSyntax.indent)\(ProcessorConstants.MermaidSyntax.root)\(ProcessorConstants.MermaidSyntax.arrow)\(ProcessorConstants.MermaidSyntax.nodeLabel)1[\"\(L10n.AI.Synthesis.Fallback.coreConcept)\"]")
        }
        return code.joined(separator: ProcessorConstants.Whitespace.newline)
    }

    /// 柔性自愈：生成结构化深度报告 (Report)
    static func generateFallbackReport(from text: String, title: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootName = cleanTitle.isEmpty ? L10n.AI.Prompt.Expert.Report.title : cleanTitle
        let lines = sanitizeSourceLines(text)

        var report = [
            "\(ProcessorConstants.MarkdownSyntax.h1Prefix)\(rootName)",
            ProcessorConstants.Whitespace.empty,
            L10n.AI.Synthesis.Fallback.reportOverview,
            String(text.prefix(ProcessorConstants.Synthesis.reportPrefixLength)),
            ProcessorConstants.Whitespace.empty,
            L10n.AI.Synthesis.Fallback.reportKeyPoints
        ]

        var count = 0
        for line in lines {
            let item = line.replacingOccurrences(of: ProcessorConstants.RegexPattern.markdownBulletStrip, with: "", options: .regularExpression)
            if item.count > ProcessorConstants.Synthesis.reportPointMinLength {
                count += 1
                report.append(L10n.AI.Synthesis.Fallback.reportPointItem(count, item))
                if count >= ProcessorConstants.Synthesis.reportMaxPoints { break }
            }
        }

        report.append(L10n.AI.Synthesis.Fallback.reportSummaryHeader)
        report.append(L10n.AI.Synthesis.Fallback.reportSummaryBody)
        return report.joined(separator: ProcessorConstants.Whitespace.newline)
    }

    /// 柔性自愈：生成知识深度扩充 (Expansion)，消除泛化“细节维度”，使用主题小节
    static func generateFallbackExpansion(from text: String, title: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootName = cleanTitle.isEmpty ? L10n.Knowledge.Page.AI.expansion : cleanTitle
        let lines = sanitizeSourceLines(text)

        let sectionTitles = [
            L10n.AI.Synthesis.Fallback.expansionSection1,
            L10n.AI.Synthesis.Fallback.expansionSection2,
            L10n.AI.Synthesis.Fallback.expansionSection3,
            L10n.AI.Synthesis.Fallback.expansionSection4
        ]

        var expansion = [
            "\(ProcessorConstants.MarkdownSyntax.h1Prefix)\(rootName)",
            ProcessorConstants.Whitespace.empty,
            L10n.AI.Synthesis.Fallback.expansionBackgroundHeader,
            lines.prefix(ProcessorConstants.Synthesis.expansionPrefixLines).joined(separator: ProcessorConstants.Whitespace.doubleNewline),
            ProcessorConstants.Whitespace.empty
        ]

        let linesPerSection = max(ProcessorConstants.Synthesis.expansionMinLinesPerSection, (lines.count - ProcessorConstants.Synthesis.expansionPrefixLines) / sectionTitles.count)
        var currentOffset = ProcessorConstants.Synthesis.expansionPrefixLines

        for secTitle in sectionTitles {
            expansion.append(secTitle)
            if currentOffset < lines.count {
                let endIdx = min(currentOffset + linesPerSection, lines.count)
                let sectionContent = lines[currentOffset..<endIdx].joined(separator: ProcessorConstants.Whitespace.doubleNewline)
                expansion.append(sectionContent)
                currentOffset = endIdx
            } else {
                expansion.append(L10n.AI.Synthesis.Fallback.expansionFiller)
            }
            expansion.append(ProcessorConstants.Whitespace.empty)
        }

        return expansion.joined(separator: ProcessorConstants.Whitespace.newline)
    }

    /// 柔性自愈：生成知识测验 (Quiz JSON)。
    /// 当 AI 生成失败时，返回通用占位提示，不硬编码任何领域知识。
    static func generateFallbackQuiz(from _: String, title: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootName = cleanTitle.isEmpty ? L10n.AI.Prompt.Quiz.defaultTitle : cleanTitle

        let placeholderDict: [String: Any] = [
            ProcessorConstants.Synthesis.quizTitleKey: L10n.AI.Synthesis.Fallback.quizInsufficientTitle(rootName),
            ProcessorConstants.Synthesis.quizQuestionsKey: [
                [
                    ProcessorConstants.Synthesis.quizIdKey: ProcessorConstants.Synthesis.quizFirstId,
                    ProcessorConstants.Synthesis.quizQuestionKey: L10n.AI.Synthesis.Fallback.quizInsufficientQuestion,
                    ProcessorConstants.Synthesis.quizOptionsKey: [L10n.AI.Synthesis.Fallback.quizInsufficientQuestion],
                    ProcessorConstants.Synthesis.quizAnswerIndexKey: ProcessorConstants.Synthesis.quizFirstId,
                    ProcessorConstants.Synthesis.quizExplanationKey: L10n.AI.Synthesis.Fallback.quizInsufficientExplanation
                ]
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: placeholderDict, options: [.prettyPrinted]),
           let jsonStr = String(data: data, encoding: .utf8) {
            return jsonStr
        }
        return ProcessorConstants.Synthesis.quizEmptyJson
    }
}

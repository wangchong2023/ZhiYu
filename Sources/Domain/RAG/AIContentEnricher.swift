//
//  AIContentEnricher.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：RAG 检索增强生成管道：语义搜索、链接发现、内容增强、评估。
//
import Foundation
import UFPCore

/// AI 内容增强处理器
/// 负责在 RAG 流程中对原始内容进行语义丰富化。
/// 通过将文档拆分为逻辑块（文本、表格、图片），利用并行任务进行针对性的语义提取。

/// 内容增强触发标记常量
private enum ContentEnrichmentMarker {
    /// Markdown 表格分隔行（含空格变体 `| --- |`）
    static let tableSeparator = "| \(SystemConstants.MarkdownSyntax.tableRowSeparator) |"
    /// Markdown 表格紧凑分隔行（无空格变体 `|---|`）
    static let compactTableSeparator = "\(SystemConstants.Character.pipe)\(SystemConstants.MarkdownSyntax.tableRowSeparator)\(SystemConstants.Character.pipe)"
    /// 图片起始标记 `![`
    static let imageStart = "!["
    /// 图片 URL 起始标记 `](`
    static let imageURLStart = "]("
    /// 表格行起始符 `|`
    static let tablePipe = SystemConstants.Character.pipe
    /// 表格分隔线特征 `---`
    static let tableDividerDashes = SystemConstants.MarkdownSyntax.tableRowSeparator
    /// Markdown 图片匹配正则 `![alt](url)`
    static let imageRegexPattern = "!\\[(.*?)\\]\\((.*?)\\)"
    static let altCaptureGroup: Int = 1
    static let urlCaptureGroup: Int = 2
    static let paragraphSeparator = SystemConstants.Character.newline + SystemConstants.Character.newline
    static let emptyString = ""
}
actor AIContentEnricher {

    static let shared = AIContentEnricher()

    private init() {}

    /// 内容块类型
    private enum ContentBlock {
        case text(String)
        case table(String)
        case image(url: String, alt: String?)
    }

    /// 对 Markdown 中的富媒体或结构化内容进行语义增强
    /// - Parameters:
    ///   - content: 原始 Markdown 文本
    ///   - llm: 调用的 LLM 服务
    /// - Returns: 增强后的文本
    func enrich(_ content: String, llm: any LLMServiceProtocol) async -> String {
        // 1. 快速判断是否需要增强（仅真实表格分隔行或完整图片语法才触发，避免 `[]` 代码数组误触发）
        let hasTable = content.contains(ContentEnrichmentMarker.tableSeparator)
            || content.contains(ContentEnrichmentMarker.compactTableSeparator)
        let hasImage = content.contains(ContentEnrichmentMarker.imageStart)
            && content.contains(ContentEnrichmentMarker.imageURLStart)
        guard hasTable || hasImage else { return content }

        // 2. 将内容拆分为逻辑块
        let blocks = parseBlocks(from: content)

        // 3. 并行处理需要增强的块
        return await withTaskGroup(of: (Int, String).self) { group in
            for (index, block) in blocks.enumerated() {
                group.addTask {
                    switch block {
                    case .text(let text):
                        return (index, text)
                    case .table(let tableContent):
                        let enriched = await self.enrichTable(tableContent, llm: llm)
                        return (index, enriched)
                    case .image(let url, let alt):
                        let enriched = await self.enrichImage(url: url, alt: alt, llm: llm)
                        return (index, enriched)
                    }
                }
            }

            var results = [(Int, String)]()
            for await result in group {
                results.append(result)
            }

            // 按原始索引排序并合并
            return results.sorted { $0.0 < $1.0 }
                .map { $0.1 }
                .joined(separator: ContentEnrichmentMarker.paragraphSeparator)
        }
    }

    // MARK: - 内部处理逻辑

    /// 解析 Markdown 块
    private func parseBlocks(from content: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let lines = content.components(separatedBy: .newlines)
        var currentText = ContentEnrichmentMarker.emptyString
        var isInsideTable = false
        var currentTable = ContentEnrichmentMarker.emptyString

        for line in lines {
            // 表格识别：以 | 开头，结束时校验是否含真实分隔行 `---`，避免普通管道符文本误送 LLM
            if line.trimmingCharacters(in: .whitespaces).hasPrefix(ContentEnrichmentMarker.tablePipe) {
                if !isInsideTable {
                    flushText(&currentText, into: &blocks)
                    isInsideTable = true
                }
                currentTable += line + SystemConstants.Character.newline
            } else {
                if isInsideTable {
                    flushTable(&currentTable, into: &blocks)
                    isInsideTable = false
                }
                if line.contains(ContentEnrichmentMarker.imageStart) && line.contains(ContentEnrichmentMarker.imageURLStart) {
                    let inlineBlocks = extractInlineImageBlocks(from: line)
                    if !inlineBlocks.isEmpty {
                        flushText(&currentText, into: &blocks)
                        blocks.append(contentsOf: inlineBlocks)
                    } else {
                        currentText += line + SystemConstants.Character.newline
                    }
                } else {
                    currentText += line + SystemConstants.Character.newline
                }
            }
        }

        // 处理最后一段
        if isInsideTable {
            flushTable(&currentTable, into: &blocks)
        } else {
            flushText(&currentText, into: &blocks)
        }

        return blocks
    }

    /// 刷新累积的表格块：仅当包含标准分隔线 `---` 时作为表格增强，否则回退为普通文本块
    private func flushTable(_ currentTable: inout String, into blocks: inout [ContentBlock]) {
        let trimmed = currentTable.trimmingCharacters(in: .whitespacesAndNewlines)
        currentTable = ContentEnrichmentMarker.emptyString
        guard !trimmed.isEmpty else { return }
        if trimmed.contains(ContentEnrichmentMarker.tableDividerDashes) {
            blocks.append(.table(trimmed))
        } else {
            blocks.append(.text(trimmed))
        }
    }

    /// 将累积的文本块刷新到 blocks 数组中，过滤纯空白块并清空缓冲区。
    private func flushText(_ currentText: inout String, into blocks: inout [ContentBlock]) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        currentText = ContentEnrichmentMarker.emptyString
        guard !trimmed.isEmpty else { return }
        blocks.append(.text(trimmed))
    }

    /// 从包含图片的文本行中按顺序拆分出所有前后文字与图片块，杜绝行内文字或多图静默丢失
    private func extractInlineImageBlocks(from line: String) -> [ContentBlock] {
        guard let regex = try? NSRegularExpression(pattern: ContentEnrichmentMarker.imageRegexPattern) else {
            return []
        }
        let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
        guard !matches.isEmpty else { return [] }

        var result: [ContentBlock] = []
        var cursor = line.startIndex

        for match in matches {
            guard let fullRange = Range(match.range, in: line),
                  let altRange = Range(match.range(at: ContentEnrichmentMarker.altCaptureGroup), in: line),
                  let urlRange = Range(match.range(at: ContentEnrichmentMarker.urlCaptureGroup), in: line) else {
                continue
            }
            if cursor < fullRange.lowerBound {
                let prefixText = String(line[cursor..<fullRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !prefixText.isEmpty {
                    result.append(.text(prefixText))
                }
            }
            result.append(.image(url: String(line[urlRange]), alt: String(line[altRange])))
            cursor = fullRange.upperBound
        }

        if cursor < line.endIndex {
            let suffixText = String(line[cursor..<line.endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !suffixText.isEmpty {
                result.append(.text(suffixText))
            }
        }
        return result
    }

    /// 增强表格语义
    private func enrichTable(_ table: String, llm: any LLMServiceProtocol) async -> String {
        let systemPrompt = L10n.AI.Prompt.enrichTableSystem
        let prompt = L10n.AI.Prompt.enrichTableUser(table)

        do {
            let insight = try await llm.generate(prompt: prompt, systemPrompt: systemPrompt)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !insight.isEmpty else { return table }
            return table + ContentEnrichmentMarker.paragraphSeparator + insight
        } catch {
            return table
        }
    }

    /// 增强图片语义 (基于上下文或元数据)
    private func enrichImage(url: String, alt: String?, llm: any LLMServiceProtocol) async -> String {
        let imageMarkdown = "![\(alt ?? ContentEnrichmentMarker.emptyString)](\(url))"
        guard let alt = alt, !alt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return imageMarkdown }

        let systemPrompt = L10n.AI.Prompt.enrichImageSystem
        let prompt = L10n.AI.Prompt.enrichImageUser(alt: alt, url: url)

        do {
            let description = try await llm.generate(prompt: prompt, systemPrompt: systemPrompt)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty else { return imageMarkdown }
            return imageMarkdown + ContentEnrichmentMarker.paragraphSeparator + description
        } catch {
            return imageMarkdown
        }
    }
}

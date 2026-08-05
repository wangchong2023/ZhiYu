//
//  DocumentSanitationEngine.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：多模态导入 (Ingest) 与 AI 知识合成 (Synthesis) 共用的文档规范化清洗引擎。
//
import Foundation

/// 全局文档规范化清洗引擎
public final class DocumentSanitationEngine: DocumentSanitizerProtocol {
    public static let shared = DocumentSanitationEngine()

    private init() {}

    public func sanitize(_ rawText: String, options: SanitizerOptions = .defaultSuite) -> String {
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        var result = rawText

        // 1. 自动剥离前导对话废话（如 "Here is the summary:"）
        if options.contains(.stripLeadingChatter) {
            result = stripLeadingChatter(result)
        }

        // 2. 剥离 HTML 冗余标签与控制字符
        if options.contains(.stripHTMLNoise) {
            result = stripHTMLNoise(result)
        }

        // 3. 合并 OCR 不自然换行
        if options.contains(.mergeOCRLineBreaks) {
            result = mergeOCRLineBreaks(result)
        }

        // 4. 应用 AST 节点级闭合与语法清理
        result = SwiftMarkdownASTCleaner.cleanAST(result)

        // 5. 应用 Mermaid 节点状态机修复
        if options.contains(.sanitizeMermaid) {
            result = MermaidSanitizer.sanitize(result)
        }

        // 6. 应用盘古中英文混排空格优化
        if options.contains(.applyPanguSpacing) {
            result = PanguFormatter.spacing(result)
        }

        return result
    }

    private func stripHTMLNoise(_ text: String) -> String {
        var clean = text
        clean = clean.replacingOccurrences(of: ProcessorConstants.SanitizationRegex.scriptBlock, with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: ProcessorConstants.SanitizationRegex.styleBlock, with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: ProcessorConstants.SanitizationRegex.allTags, with: "", options: .regularExpression)
        return clean
    }

    private func mergeOCRLineBreaks(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var merged: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                merged.append("")
                continue
            }
            if trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.hash) || trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.dash) || trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.asterisk) || trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.greaterThan) || trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.codeFence) {
                merged.append(line)
                continue
            }
            if let last = merged.last, !last.isEmpty, !last.hasPrefix(ProcessorConstants.MarkdownSyntax.hash), !last.hasPrefix(ProcessorConstants.MarkdownSyntax.dash), !last.hasPrefix(ProcessorConstants.MarkdownSyntax.asterisk), !last.hasPrefix(ProcessorConstants.MarkdownSyntax.greaterThan), !last.hasPrefix(ProcessorConstants.MarkdownSyntax.codeFence) {
                merged[merged.count - 1] = last + ProcessorConstants.Whitespace.space + trimmed
            } else {
                merged.append(line)
            }
        }
        return merged.joined(separator: ProcessorConstants.Whitespace.newline)
    }

    private func stripLeadingChatter(_ text: String) -> String {
        let lines = text.components(separatedBy: ProcessorConstants.Whitespace.newline)
        guard let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) else { return text }

        let lower = firstLine.lowercased()
        // 使用全语种前缀集合，覆盖所有支持语言（中/英/日/韩/法/西/阿/俄/葡/繁中）
        // 无论用户当前系统语言为何，均能匹配 LLM 输出的多语言前导废话
        let allPrefixes = L10n.AI.Synthesis.Fallback.allChatterPrefixes
        for prefix in allPrefixes {
            if lower.hasPrefix(prefix.lowercased()) && firstLine.contains(":") {
                return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text
    }
}

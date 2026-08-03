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
        clean = clean.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
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
            if trimmed.hasPrefix("#") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix(">") || trimmed.hasPrefix("```") {
                merged.append(line)
                continue
            }
            if let last = merged.last, !last.isEmpty, !last.hasPrefix("#"), !last.hasPrefix("-"), !last.hasPrefix("*"), !last.hasPrefix(">"), !last.hasPrefix("```") {
                merged[merged.count - 1] = last + " " + trimmed
            } else {
                merged.append(line)
            }
        }
        return merged.joined(separator: "\n")
    }

    /// 英文前导对话废话匹配规则（LLM 输出常为英文，需独立于当前语言环境匹配）
    /// 这些是匹配规则而非 UI 展示文本，与 L10n.chatterPrefixes 互补使用
    private static let englishChatterPrefixes: [String] = [
        "here is", "here's", "here are", "below is", "below are",
        "this is", "following is", "as requested", "parsed as"
    ]

    private func stripLeadingChatter(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        guard let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) else { return text }

        let lower = firstLine.lowercased()
        // 合并当前语言前缀（L10n）与英文前缀（匹配规则），实现多语言覆盖
        let allPrefixes = L10n.AI.Synthesis.Fallback.chatterPrefixes + Self.englishChatterPrefixes
        for prefix in allPrefixes {
            if lower.hasPrefix(prefix.lowercased()) && firstLine.contains(":") {
                return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text
    }
}

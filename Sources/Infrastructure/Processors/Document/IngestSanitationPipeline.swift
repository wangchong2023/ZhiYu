//
//  IngestSanitationPipeline.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：多模态导入 (Ingest) 专用文本规范化与清洗流水线适配器。
//
import Foundation

/// 导入源模态枚举
public enum IngestSourceMode: String, Sendable, CaseIterable {
    case ocr
    case voiceNote
    case webClip
    case document
    case plainMarkdown
}

/// 统一多模态导入清洗流水线适配器
public final class IngestSanitationPipeline: Sendable {
    public static let shared = IngestSanitationPipeline()

    private init() {}

    /// 针对特定导入源模态，应用优化的清洗策略与 SanitizerOptions
    /// - Parameters:
    ///   - rawContent: 原始转换文本
    ///   - mode: 导入源模态 (OCR / 语音笔记 / 网页剪藏 / 格式文档 / 纯 Markdown)
    /// - Returns: 清洗美化后的规范 Markdown 文本
    public func sanitize(_ rawContent: String, mode: IngestSourceMode) -> String {
        guard !rawContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        let options: SanitizerOptions
        switch mode {
        case .ocr:
            options = [.applyPanguSpacing, .sanitizeMermaid, .mergeOCRLineBreaks, .stripHTMLNoise]
        case .voiceNote:
            options = [.applyPanguSpacing, .stripLeadingChatter]
        case .webClip:
            options = [.applyPanguSpacing, .sanitizeMermaid, .stripHTMLNoise, .stripLeadingChatter]
        case .document, .plainMarkdown:
            options = .defaultSuite
        }

        return DocumentSanitationEngine.shared.sanitize(rawContent, options: options)
    }
}

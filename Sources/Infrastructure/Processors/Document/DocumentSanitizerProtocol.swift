//
//  DocumentSanitizerProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：定义统一的文档清洗与规范化能力协议 (用于 Ingest 与 Synthesis 复用)。
//
import Foundation

/// 统一文档清洗选项
public struct SanitizerOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// 应用中英文混排空格美化 (Pangu)
    public static let applyPanguSpacing = SanitizerOptions(rawValue: 1 << 0)
    /// 应用 Mermaid 节点状态机语法纠错
    public static let sanitizeMermaid = SanitizerOptions(rawValue: 1 << 1)
    /// 自动剥离前导与后置杂质引言
    public static let stripLeadingChatter = SanitizerOptions(rawValue: 1 << 2)
    /// 自动合并 OCR 断字与不自然换行
    public static let mergeOCRLineBreaks = SanitizerOptions(rawValue: 1 << CoreConstants.BitShift.bit3)
    /// 自动剥离 HTML 冗余标签与控制字符
    public static let stripHTMLNoise = SanitizerOptions(rawValue: 1 << CoreConstants.BitShift.bit4)

    /// 默认全套开启
    public static let defaultSuite: SanitizerOptions = [.applyPanguSpacing, .sanitizeMermaid, .stripLeadingChatter, .mergeOCRLineBreaks, .stripHTMLNoise]
}

/// 统一文档清洗能力协议
public protocol DocumentSanitizerProtocol: Sendable {
    /// 执行文档清洗与规范化
    /// - Parameters:
    ///   - rawText: 原始多模态转写文本或大模型生成文本
    ///   - options: 清洗选项配置
    /// - Returns: 格式化后的规范 Markdown 文本
    func sanitize(_ rawText: String, options: SanitizerOptions) -> String
}

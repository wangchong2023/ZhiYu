//
//  SynthesisProcessor+Helpers.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：SynthesisProcessor 重复代码抽取辅助方法（标题解析、项目符号剥离、行清洗）。
//
import Foundation

// MARK: - 合成处理器辅助方法

extension SynthesisProcessor {

    /// 解析兜底标题：若传入标题为空或为 Prompt 控制参数，则使用指定默认标题
    /// - Parameters:
    ///   - title: 原始标题
    ///   - fallback: 标题为空时的默认标题
    /// - Returns: 清洗后的有效根标题
    static func resolveFallbackTitle(_ title: String, fallback: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanTitle.isEmpty ? fallback : cleanTitle
    }

    /// 剥离 Markdown 行首项目符号/编号前缀并去除首尾空白
    /// - Parameter line: 原始行文本
    /// - Returns: 去除项目符号后的纯文本
    static func stripBulletPrefix(_ line: String) -> String {
        line.replacingOccurrences(of: ProcessorConstants.RegexPattern.markdownBulletStrip, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// 剥离项目符号并将双引号转义为单引号（用于 Mermaid 节点文本安全化）
    /// - Parameter line: 原始行文本
    /// - Returns: 安全化后的节点文本
    static func stripBulletAndEscapeQuotes(_ line: String) -> String {
        stripBulletPrefix(line)
            .replacingOccurrences(of: ProcessorConstants.MarkdownSyntax.doubleQuote, with: ProcessorConstants.MarkdownSyntax.singleQuote)
    }

    /// 将文本按行拆分并去除每行首尾空白（用于合成源行清洗）
    /// - Parameter text: 原始文本
    /// - Returns: 去除空白后的行数组
    static func splitAndTrimLines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

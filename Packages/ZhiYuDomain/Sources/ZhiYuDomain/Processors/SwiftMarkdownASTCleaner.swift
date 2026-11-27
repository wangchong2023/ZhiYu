//
//  SwiftMarkdownASTCleaner.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：基于 CommonMark/GFM 规范进行 Markdown 节点级 AST 清洗与格式自动修补。
//
import Foundation

/// Markdown 抽象语法树节点清洗器
public enum SwiftMarkdownASTCleaner {
    /// 执行 AST 节点级清洗与格式规整
    /// - Parameter markdown: 原始 Markdown 文本
    /// - Returns: 闭合修复与规整后的 Markdown 文本
    public static func cleanAST(_ markdown: String) -> String {
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }

        var result = markdown

        // 1. 自动补全未闭合的 ``` 代码块
        let fenceCount = result.components(separatedBy: ProcessorConstants.MarkdownSyntax.codeFence).count - 1
        if fenceCount % 2 != 0 {
            result.append(ProcessorConstants.Whitespace.newline + ProcessorConstants.MarkdownSyntax.codeFence + ProcessorConstants.Whitespace.newline)
        }

        // 2. 补全未闭合的粗体语法标记（忽略围栏代码块内的 **，如 Python 幂运算或 C 二级指针）
        let asteriskCount = countUnfencedBoldMarkers(in: result)
        if asteriskCount % 2 != 0 {
            result.append(ProcessorConstants.MarkdownSyntax.bold)
        }

        // 3. 规范连续多余空行
        while result.contains(ProcessorConstants.Whitespace.tripleNewline) {
            result = result.replacingOccurrences(of: ProcessorConstants.Whitespace.tripleNewline, with: ProcessorConstants.Whitespace.doubleNewline)
        }

        return result
    }

    /// 统计围栏代码块（```）之外正文中 `**` 标记的出现次数，避免误伤代码中的幂运算或指针符号
    private static func countUnfencedBoldMarkers(in markdown: String) -> Int {
        let segments = markdown.components(separatedBy: ProcessorConstants.MarkdownSyntax.codeFence)
        var count = 0
        for (index, segment) in segments.enumerated() where index % 2 == 0 {
            count += segment.components(separatedBy: ProcessorConstants.MarkdownSyntax.bold).count - 1
        }
        return count
    }
}

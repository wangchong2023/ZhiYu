//
//  CJKSpacingFormatter.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：CJK (中日韩) 字符与 ANSI (英文/数字) 混排自动注入空格与排版美化引擎。
//
import Foundation

/// CJK (中日韩) 与 ANSI (英文/数字) 混排空格优化器
public enum CJKSpacingFormatter {

    /// 在 CJK (中日韩) 字符与 ANSI (英文/数字) 字符之间自动注入空格，提升可读性
    /// - Parameter text: 原始 Markdown/Plain text 字符串
    /// - Returns: 优化排版后的文本
    public static func spacing(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var result = text

        // CJK 字符与英文/数字之间插入空格
        result = applyBoundarySpacing(pattern: ProcessorConstants.RegexPattern.cjkAnsBoundary, to: result)
        result = applyBoundarySpacing(pattern: ProcessorConstants.RegexPattern.ansCjkBoundary, to: result)

        return result
    }

    /// 共享的 CJK/ANSI 边界空格注入辅助，委托 applyCaptureGroupReplacement 消除正则替换样板。
    private static func applyBoundarySpacing(pattern: String, to text: String) -> String {
        applyCaptureGroupReplacement(text, pattern: pattern)
    }
}

/// 向后兼容类型别名
public typealias PanguFormatter = CJKSpacingFormatter

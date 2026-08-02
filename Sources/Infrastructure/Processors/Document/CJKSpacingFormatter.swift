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
        let cjkAnsRegex = try? NSRegularExpression(pattern: #"([\u4e00-\u9fa5\u3040-\u30ff])([A-Za-z0-9@#\$%\^&\*\-\+\=])"#)
        let ansCjkRegex = try? NSRegularExpression(pattern: #"([A-Za-z0-9@#\$%\^&\*\-\+\=])([\u4e00-\u9fa5\u3040-\u30ff])"#)

        if let regex = cjkAnsRegex {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1 $2")
        }
        if let regex = ansCjkRegex {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1 $2")
        }

        return result
    }
}

/// 向后兼容类型别名
public typealias PanguFormatter = CJKSpacingFormatter

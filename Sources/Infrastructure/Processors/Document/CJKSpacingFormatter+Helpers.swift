//
//  CJKSpacingFormatter+Helpers.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：CJKSpacingFormatter 重复代码抽取辅助方法（正则替换公共逻辑）。
//
import Foundation

// MARK: - CJK 空格优化辅助方法

extension CJKSpacingFormatter {

    /// 使用指定正则模式替换文本中的匹配项为捕获组 1 + 空格 + 捕获组 2
    /// - Parameters:
    ///   - text: 原始文本
    ///   - pattern: 正则模式
    /// - Returns: 替换后的文本
    static func applyCaptureGroupReplacement(_ text: String, pattern: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: ProcessorConstants.RegexPattern.captureGroup12
        )
    }
}

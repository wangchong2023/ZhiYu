//
//  CJKSpacingFormatter+Helpers.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：CJKSpacingFormatter 正则替换辅助方法（委托 UFPCore.RegexReplacementHelper，消除重复实现）。
//
import Foundation
import UFPCore

// MARK: - CJK 空格优化辅助方法

extension CJKSpacingFormatter {

    /// 使用指定正则模式替换文本中的匹配项为捕获组 1 + 空格 + 捕获组 2
    /// - Parameters:
    ///   - text: 原始文本
    ///   - pattern: 正则模式
    /// - Returns: 替换后的文本
    static func applyCaptureGroupReplacement(_ text: String, pattern: String) -> String {
        RegexReplacementHelper.applyCaptureGroupReplacement(text, pattern: pattern)
    }
}

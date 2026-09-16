//
//  ThinkingProcessor+Helpers.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：ThinkingProcessor 重复代码抽取辅助方法（thinking/main 分割提取）。
//
import Foundation

// MARK: - 思考过程提取辅助方法

extension ThinkingProcessor {

    /// 在分隔符位置将文本分割为 thinking 与 main 两部分
    /// - Parameters:
    ///   - text: 原始文本
    ///   - dividerRange: 分隔符范围
    /// - Returns: (thinking, main) 元组，均已去除首尾空白
    static func splitAtDivider(_ text: String, dividerRange: Range<String.Index>) -> (thinking: String, main: String) {
        let thinking = String(text[..<dividerRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let main = String(text[dividerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (thinking, main)
    }

    /// 构造思考提取结果，thinking 为空时返回 nil
    /// - Parameters:
    ///   - thinking: 思考过程文本
    ///   - main: 正文文本
    /// - Returns: Result 实例
    static func makeResult(thinking: String, main: String) -> Result {
        Result(thinkingContent: thinking.isEmpty ? nil : thinking, mainContent: main)
    }
}

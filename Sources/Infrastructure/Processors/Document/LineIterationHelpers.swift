//
//  LineIterationHelpers.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：文档行遍历过滤公共辅助方法，消除多处理器中的行遍历模板重复。
//
import Foundation

// MARK: - 行遍历过滤辅助

/// 文档行遍历过滤的公共辅助方法集
enum LineIterationHelpers {

    /// 遍历行数组，跳过空行和以指定前缀开头的行，对剩余行执行闭包
    /// - Parameters:
    ///   - lines: 原始行数组
    ///   - skipPrefixes: 需要跳过的行首前缀集合
    ///   - body: 对有效行执行的闭包（传入 trimmed 行）
    static func iterateNonEmptyLines(
        _ lines: [String],
        skipPrefixes: [String] = [],
        body: (String) -> Void
    ) {
        for (trimmed, _) in nonEmptyTrimmedLines(lines) {
            if skipPrefixes.contains(where: { trimmed.hasPrefix($0) }) { continue }
            body(trimmed)
        }
    }

    /// 遍历行数组，跳过空行，对剩余行执行闭包（不跳过任何前缀）
    /// - Parameters:
    ///   - lines: 原始行数组
    ///   - body: 对有效行执行的闭包（传入 trimmed 行和原始行）
    static func iterateTrimmedLines(
        _ lines: [String],
        body: (String, String) -> Void
    ) {
        for (trimmed, original) in nonEmptyTrimmedLines(lines) {
            body(trimmed, original)
        }
    }

    /// 共享的非空行遍历核心：跳过空行，返回 (trimmed, original) 序列，消除两个遍历方法间的样板重复。
    private static func nonEmptyTrimmedLines(_ lines: [String]) -> [(String, String)] {
        lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : (trimmed, line)
        }
    }
}

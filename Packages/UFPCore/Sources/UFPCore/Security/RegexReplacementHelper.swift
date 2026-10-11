//
//  RegexReplacementHelper.swift
//  UFPCore
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：提供 NSRegularExpression 替换匹配的公共辅助方法，消除 Security 模块内重复的正则替换代码块。
//
import Foundation

/// 正则替换公共辅助
/// 抽取 PIIMasker / SecurityReinforcement / PromptSanitizer / ContentModerationEngine 中重复的
/// `NSRegularExpression` 构造 + `stringByReplacingMatches` 调用模式。
public enum RegexReplacementHelper {

    /// 正则替换模板常量
    private enum RegexTemplate {
        /// 捕获组 1 + 空格 + 捕获组 2 的替换模板（取自 ProcessorConstants.RegexPattern.captureGroup12）
        static let captureGroup12: String = "$1 $2"
    }

    /// 对文本依次应用一组 (pattern, template) 替换规则
    /// - Parameters:
    ///   - text: 原始文本
    ///   - rules: (正则模式, 替换模板) 列表
    /// - Returns: 全部规则应用后的文本；正则构造失败的规则会被跳过
    public static func applyReplacements(_ text: String, rules: [(pattern: String, template: String)]) -> String {
        var result = text
        for rule in rules {
            if let regex = try? NSRegularExpression(pattern: rule.pattern, options: []) {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: rule.template
                )
            }
        }
        return result
    }

    /// 对文本依次应用一组正则模式进行匹配检测（不替换）
    /// - Parameters:
    ///   - text: 待检测文本
    ///   - patterns: 正则模式列表
    /// - Returns: 任一模式命中即返回 true
    public static func matchesAny(_ text: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: text.utf16.count)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    return true
                }
            }
        }
        return false
    }

    /// 使用指定正则模式替换文本中的匹配项为捕获组 1 + 空格 + 捕获组 2
    /// - Parameters:
    ///   - text: 原始文本
    ///   - pattern: 正则模式
    /// - Returns: 替换后的文本
    public static func applyCaptureGroupReplacement(_ text: String, pattern: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: RegexTemplate.captureGroup12
        )
    }
}
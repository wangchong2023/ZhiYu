//
//  RegexReplacementHelper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：提供 NSRegularExpression 替换匹配的公共辅助方法，消除 Security 模块内重复的正则替换代码块。
//
import Foundation

/// 正则替换公共辅助
/// 抽取 PIIMasker / SecurityReinforcement / PromptSanitizer / ContentModerationEngine 中重复的
/// `NSRegularExpression` 构造 + `stringByReplacingMatches` 调用模式。
enum RegexReplacementHelper {

    /// 对文本依次应用一组 (pattern, template) 替换规则
    /// - Parameters:
    ///   - text: 原始文本
    ///   - rules: (正则模式, 替换模板) 列表
    /// - Returns: 全部规则应用后的文本；正则构造失败的规则会被跳过
    static func applyReplacements(_ text: String, rules: [(pattern: String, template: String)]) -> String {
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
    static func matchesAny(_ text: String, patterns: [String]) -> Bool {
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
}

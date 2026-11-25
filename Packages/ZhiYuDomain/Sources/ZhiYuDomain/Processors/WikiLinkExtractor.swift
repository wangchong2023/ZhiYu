//
//  WikiLinkExtractor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：统一的双向链接 [[页面标题]] 提取器 (用于 Ingest 与 Synthesis 复用)。
//
import Foundation

/// 双向链接结构定义
public struct WikiLinkMatch: Identifiable, Equatable, Sendable {
    public var id: String { rawMatch }
    public let rawMatch: String
    public let targetTitle: String
    public let alias: String?
    public var displayTitle: String {
        alias ?? targetTitle
    }
}

/// 全局双向链接提取工具
public enum WikiLinkExtractor {
    /// 匹配 [[页面标题]] 或 [[页面标题|别名]] 的正则
    private static let linkRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"(?<!\\)\[\[([^\]\|]+)(?:\|([^\]]+))?\]\]"#)
    }()

    /// 从任意 Markdown 文本中提取所有双向链接
    /// - Parameter text: Markdown 文本
    /// - Returns: WikiLinkMatch 结构数组
    public static func extractLinks(from text: String) -> [WikiLinkMatch] {
        guard let regex = linkRegex, !text.isEmpty else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        var result: [WikiLinkMatch] = []
        for match in matches {
            guard let rawRange = Range(match.range(at: 0), in: text),
                  let titleRange = Range(match.range(at: 1), in: text) else { continue }

            let rawMatch = String(text[rawRange])
            let targetTitle = String(text[titleRange]).trimmingCharacters(in: .whitespaces)

            var alias: String?
            if match.numberOfRanges > 2, let aliasRange = Range(match.range(at: 2), in: text) {
                alias = String(text[aliasRange]).trimmingCharacters(in: .whitespaces)
            }

            if !targetTitle.isEmpty {
                result.append(WikiLinkMatch(rawMatch: rawMatch, targetTitle: targetTitle, alias: alias))
            }
        }
        return result
    }
}

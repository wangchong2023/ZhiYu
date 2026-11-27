//
//  AppLinkProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：深度链接与通用链接解析，将外部 URL 映射为内部 AppRoute。
//
import Foundation
import UFPCore

/// 知识库链接处理器：负责处理 [[applinks]] 的解析与管理
struct AppLinkProcessor {

    private enum LinkSyntax {
        /// 单行双链正则（禁止跨行误吞多段正文）
        static let pattern = #"\[\[([^\]\r\n]+)\]\]"#
        /// 别名分隔符（如 [[Target|Alias]]）
        static let aliasSeparator: Character = "|"
        /// 章节锚点分隔符（如 [[Target#Heading]]）
        static let headingSeparator: Character = "#"
    }

    /// 从 Markdown 文本中提取所有 App-link 的目标标题（自动剥离 | 别名与 # 锚点并过滤空白）
    /// - Parameter content: 原始 Markdown 内容
    /// - Returns: 提取到的标题列表（已去重、按字典序排序）
    static func extractOutgoingLinks(from content: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: LinkSyntax.pattern) else { return [] }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        let links = matches.compactMap { match -> String? in
            guard match.numberOfRanges > 1 else { return nil }
            let rawInner = nsContent.substring(with: match.range(at: 1))
            let withoutAlias = rawInner.split(separator: LinkSyntax.aliasSeparator, maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? rawInner
            let withoutHeading = withoutAlias.split(separator: LinkSyntax.headingSeparator, maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? withoutAlias
            let normalized = withoutHeading.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? nil : normalized
        }

        return Array(Set(links)).sorted()
    }
}

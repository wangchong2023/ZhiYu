//
//  CreatePageContentBuilder.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：规范化构建新建页面的 Markdown 正文、WikiLink 双向链接与对比标题
//

import Foundation
import UFPCore

/// 新建页面 Markdown 内容与双向链接构建器
public enum CreatePageContentBuilder {

    /// 将用户输入的逗号分隔关联页面转换为标准 Markdown WikiLink 列表
    /// - Parameters:
    ///   - rawItems: 原始逗号分隔字符串
    ///   - headerTitle: 分区标题
    /// - Returns: Markdown 分区文本
    public static func buildRelatedSection(from rawItems: String, headerTitle: String) -> String {
        let links = rawItems.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !links.isEmpty else { return "" }

        let formattedLinks = links.map { item -> String in
            if item.hasPrefix(CoreConstants.MarkdownSyntax.wikiLinkOpen) && item.hasSuffix(CoreConstants.MarkdownSyntax.wikiLinkClose) {
                return "- \(item)"
            } else {
                return "- [[\(item)]]"
            }
        }

        return "\n## \(headerTitle)\n" + formattedLinks.joined(separator: "\n") + "\n"
    }

    /// 构建对比页面的标题头部
    /// - Parameters:
    ///   - itemA: 对比项 A
    ///   - itemB: 对比项 B
    /// - Returns: Markdown 标题
    public static func buildComparisonHeader(itemA: String, itemB: String) -> String {
        let a = itemA.trimmingCharacters(in: .whitespaces)
        let b = itemB.trimmingCharacters(in: .whitespaces)
        if !a.isEmpty || !b.isEmpty {
            return "## \(a) vs \(b)\n\n"
        }
        return ""
    }

    /// 构建页面完整的 Markdown 正文
    public static func buildContent(
        type: PageType,
        summary: String,
        bodyContent: String,
        relatedItems: String,
        compareItemA: String = "",
        compareItemB: String = "",
        relatedLinksHeader: String
    ) -> String {
        let compareHeader = type == .comparison ? buildComparisonHeader(itemA: compareItemA, itemB: compareItemB) : ""
        let relatedSection = buildRelatedSection(from: relatedItems, headerTitle: relatedLinksHeader)

        return """
        \(compareHeader)\(summary)

        \(bodyContent)
        \(relatedSection)
        """
    }
}

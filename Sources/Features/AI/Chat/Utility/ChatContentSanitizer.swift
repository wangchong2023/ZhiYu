//
//  ChatContentSanitizer.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：提供对话内容清洗、转义修复、双链跳转页面解析与引用页面有效性校验
//

import Foundation
import UFPCore

/// 对话内容与 Markdown 转义清洗处理器
public enum ChatContentSanitizer {

    /// 清理大模型生成的 Markdown 常见转义字符（\` \* \_ \[\[ \]\] 等）
    /// - Parameter text: 待清洗的原始文本
    /// - Returns: 清洗修复后的 Markdown 文本
    public static func sanitizeEscapes(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        let cleaned = text
            .replacingOccurrences(of: FeatureConstants.RegexEscape.escapedBacktick, with: SystemConstants.Character.backtick)
            .replacingOccurrences(of: FeatureConstants.RegexEscape.escapedAsterisk, with: SystemConstants.Character.asterisk)
            .replacingOccurrences(of: FeatureConstants.RegexEscape.escapedUnderscore, with: SystemConstants.Character.underscore)
        return restoreWikiLinkSyntax(in: cleaned)
    }

    /// 还原双链语法：将转义的 `[[` 和 `]]` 还原为原始 Wiki Link 标记
    /// - Parameter text: 待处理的文本
    /// - Returns: 还原后的文本
    public static func restoreWikiLinkSyntax(in text: String) -> String {
        text
            .replacingOccurrences(of: FeatureConstants.RegexEscape.escapedWikiLinkOpen, with: SystemConstants.MarkdownSyntax.wikiLinkOpen)
            .replacingOccurrences(of: FeatureConstants.RegexEscape.escapedWikiLinkClose, with: SystemConstants.MarkdownSyntax.wikiLinkClose)
    }

    /// 在知识库页面集合中匹配双链目标页面（优先精确匹配标题，次之大小写不敏感，最后遍历别名）
    /// - Parameters:
    ///   - title: 双链目标标题或别名
    ///   - pages: 知识库页面候选集合
    /// - Returns: 匹配到的知识库页面对象，未找到返回 nil
    public static func resolveTargetPage(title: String, pages: [KnowledgePage]) -> KnowledgePage? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. 优先按标题严格大小写不敏感匹配
        if let directMatch = pages.first(where: {
            $0.title.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return directMatch
        }

        // 2. 次之按别名大小写不敏感匹配
        if let aliasMatch = pages.first(where: { page in
            page.aliases.contains { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
        }) {
            return aliasMatch
        }

        return nil
    }

    /// 过滤并提取有效的被引用知识库页面（杜绝已删除页面的幽灵引用展示）
    /// - Parameters:
    ///   - pageIDs: 引用的页面 ID 列表
    ///   - pages: 当前知识库页面集合
    /// - Returns: 实际存在于知识库中的有效页面列表（保持去重与输入顺序）
    public static func filterValidPages(pageIDs: [UUID], pages: [KnowledgePage]) -> [KnowledgePage] {
        guard !pageIDs.isEmpty && !pages.isEmpty else { return [] }

        var seen = Set<UUID>()
        var valid: [KnowledgePage] = []
        let pageMap = Dictionary(pages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for id in pageIDs where !seen.contains(id) {
            seen.insert(id)
            if let page = pageMap[id] {
                valid.append(page)
            }
        }

        return valid
    }
}

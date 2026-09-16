//
//  WikiLinkTextSanitizer.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/15.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Wiki Link 文本清理工具，消除 ImportRecordSection 与 VoiceAudioPlayerView 的重复 replacingOccurrences 链。
//

import UFPCore

/// Wiki Link 文本清理工具，消除跨文件的 wikiLinkOpen/wikiLinkClose 替换重复
enum WikiLinkTextSanitizer {
    /// 将 `[[title]]` 形式的 wiki link 标记替换为「title」中文引号，用于纯文本预览展示
    static func convertToQuoted(_ text: String) -> String {
        text
            .replacingOccurrences(of: SystemConstants.MarkdownSyntax.wikiLinkOpen, with: "「")
            .replacingOccurrences(of: SystemConstants.MarkdownSyntax.wikiLinkClose, with: "」")
    }
}

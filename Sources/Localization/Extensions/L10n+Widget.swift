//
//  L10n+Widget.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Widget 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public struct Widget: L10nTableEntry {
        public static let tableName = "Platform"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        public static var title: String { Localized.tr("widget.title", table: t) }
        public static var pages: String { Localized.tr("widget.pages", table: t) }
        public static var words: String { Localized.tr("widget.words", table: t) }
        public static var active: String { L10n.Common.tr("status.active") }
        public static var characters: String { Localized.tr("widget.characters", table: t) }
        public static var recentUpdates: String { L10n.Common.tr("recentUpdates") }
        public static var stub: String { L10n.Common.tr("status.stub") }
        public static var knowledgeCompile: String { Localized.tr("widget.knowledgeCompile", table: t) }
        public static var aiChat: String { L10n.Common.tr("tab.chat") }
        public static var search: String { L10n.Common.tr("components.search") }
        public static var links: String { L10n.Common.tr("accessibility.links") }
        public static var tags: String { L10n.Common.tr("accessibility.tags") }
        public static var vaultName: String { Localized.tr("widget.vaultName", table: t) }
        public static var ai: String { Localized.tr("widget.ai", table: t) }
        public static var dailyInsight: String { Localized.tr("widget.dailyInsight", table: t) }
        public static var knowledgeDistribution: String { Localized.tr("widget.knowledgeDistribution", table: t) }
        public static var voice: String { L10n.Common.tr("tab.voice") }
        public static var qa: String { Localized.tr("widget.qa", table: t) }
        public static var ocr: String { Localized.tr("widget.ocr", table: t) }
        public static var dictating: String { Localized.tr("widget.dictating", table: t) }
        public static var voiceFlashCapture: String { Localized.tr("widget.voiceFlashCapture", table: t) }
        public static var syncedToiOS: String { Localized.tr("widget.syncedToiOS", table: t) }
        public static var llmWikiChunking: String { Localized.tr("widget.llmWikiChunking", table: t) }
        public static var llmWikiDescription: String { Localized.tr("widget.llmWikiDescription", table: t) }
        public static var flashThoughtSub: String { Localized.tr("widget.flashThoughtSub", table: t) }
        public static var insightQuote1: String { Localized.tr("widget.insightQuote1", table: t) }
        public static var insightQuote2: String { Localized.tr("widget.insightQuote2", table: t) }
        public static var insightQuote3: String { Localized.tr("widget.insightQuote3", table: t) }
        public static var sampleVoiceNote: String { Localized.tr("widget.sampleVoiceNote", table: t) }
        public static var zhiyuAI: String { Localized.tr("widget.zhiyuAI", table: t) }
        public static var widgetsPreview: String { Localized.tr("widget.widgetsPreview", table: t) }
        public static var watchVoiceCapture: String { Localized.tr("widget.watchVoiceCapture", table: t) }

        /// pages
        /// - Parameter n: n
        /// - Returns: 字符串
        public static func pages(_ n: Int) -> String { Localized.trf("pagesCount", table: t, n) }
    }
}

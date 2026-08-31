//
//  WidgetL10n.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：Widget Extension 独立本地化助手。
//           Widget 无法引入主 App 的 L10n 模块，故通过 String(localized:)
//           直接读取 Platform.xcstrings 中的 Widget 相关词条。
//
import Foundation

/// Widget 专用本地化命名空间，API 与 L10n.Widget 保持一致。
enum WidgetL10n {
    static var vaultName: String { String(localized: "widget.vaultName", table: "Platform") }
    static var create: String { String(localized: "logAction.create", table: "Common") }
    static var links: String { String(localized: "accessibility.links", table: "Common") }
    static var tags: String { String(localized: "accessibility.tags", table: "Common") }
    static var aiChat: String { String(localized: "widget.aiChat", table: "Platform") }
    static var search: String { String(localized: "components.search", table: "Common") }
    static var ai: String { String(localized: "widget.ai", table: "Platform") }
    static var title: String { String(localized: "widget.title", table: "Platform") }
    static var recentUpdates: String { String(localized: "widget.recentUpdates", table: "Platform") }
    static var dailyInsight: String { String(localized: "widget.dailyInsight", table: "Platform") }
    static var knowledgeDistribution: String { String(localized: "widget.knowledgeDistribution", table: "Platform") }
    static var voice: String { String(localized: "tab.voice", table: "Common") }
    static var qa: String { String(localized: "widget.qa", table: "Platform") }
    static var llmWikiChunking: String { String(localized: "widget.llmWikiChunking", table: "Platform") }
    static var llmWikiDescription: String { String(localized: "widget.llmWikiDescription", table: "Platform") }
    static var flashThoughtSub: String { String(localized: "widget.flashThoughtSub", table: "Platform") }
    static var insightQuote1: String { String(localized: "widget.insightQuote1", table: "Platform") }
    static var insightQuote2: String { String(localized: "widget.insightQuote2", table: "Platform") }
    static var insightQuote3: String { String(localized: "widget.insightQuote3", table: "Platform") }
    static var weeklyHeatmap: String { String(localized: "widget.weeklyHeatmap", table: "Platform") }
    static var quickCaptureTitle: String { String(localized: "widget.quickCaptureTitle", table: "Platform") }
    static var source: String { String(localized: "widget.source", table: "Platform") }
    static var concept: String { String(localized: "widget.concept", table: "Platform") }
    static var entity: String { String(localized: "widget.entity", table: "Platform") }
    static var map: String { String(localized: "widget.map", table: "Platform") }
    static var ocr: String { String(localized: "widget.ocr", table: "Platform") }
}

//
//  L10n+Lint.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Lint 模块提供本地化强类型字符串的访问扩展。
//
import Foundation
import UFPCore

extension L10n {
    public struct Lint: L10nTableEntry {
        public static let tableName = "System"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        public static var title: String { Localized.tr("lint.title", table: t) }
        public static var refactorSection: String { tr("refactorSection") }
        public static var linkDiscoverySection: String { tr("linkDiscoverySection") }
        public static var healthExcellent: String { tr("health.excellent") }
        public static var healthGood: String { tr("health.good") }
        public static var healthFair: String { tr("health.fair") }
        public static var healthPoor: String { tr("health.poor") }
        public static var islandMessage: String { tr("island.message") }
        public static var islandSuggestion: String { tr("island.suggestion") }
        public static var orphanPage: String { tr("orphan.page") }
        public static var orphanSuggestion: String { tr("orphan.suggestion") }
        public static var cycleMessage: String { tr("cycle.message") }
        public static var cycleSuggestion: String { Localized.tr("lint.cycleSuggestion", table: t) }
        public static var brokenLink: String { tr("brokenLink.message") }
        public static var brokenLinkSuggestion: String { tr("brokenLink.suggestion") }
        public static var stubContent: String { tr("stub.message") }
        public static var stubSuggestion: String { Localized.tr("lint.stubSuggestion", table: t) }
        public static var outdated: String { tr("outdated.message") }
        public static var outdatedSuggestion: String { Localized.tr("lint.outdatedSuggestion", table: t) }

        /// duplicateTitleMessage
        /// - Parameter title: title
        /// - Returns: 字符串
        public static func duplicateTitleMessage(_ title: String) -> String { Localized.trf("duplicateTitle.message", table: t, title) }
        public static var duplicateTitleSuggestion: String { tr("duplicateTitle.suggestion") }
        public static var aiSuggestions: String { tr("aiSuggestions") }
        public static var detailIssues: String { tr("detailIssues") }
        public static var lastCheckTitle: String { tr("lastCheckTitle") }
        public static var lastCheckNever: String { tr("lastCheckNever") }
        public static var metricPages: String { tr("metric.pages") }
        public static var metricBroken: String { tr("metric.broken") }
        public static var metricOrphans: String { tr("metric.orphans") }
        public static var metricLinks: String { tr("metric.links") }
        public static var noIssues: String { tr("noIssues") }
        public static var noIssuesHint: String { tr("noIssuesHint") }
        public static var noAISuggestions: String { tr("noAISuggestions") }
        public static var noAISuggestionsHint: String { tr("noAISuggestionsHint") }
        public static var scanComplete: String { tr("scanComplete") }
        public static var scanning: String { tr("scanning") }
        public static var aiDisabledHint: String { tr("aiDisabledHint") }
        public static var aiScanComplete: String { tr("aiScanComplete") }
        public static var apply: String { tr("apply") }
        public static var runCheck: String { tr("runCheck") }
        public static var runAIScan: String { tr("runAIScan") }
        public static var goToPage: String { tr("goToPage") }

        /// errors
        /// - Parameter n: n
        /// - Returns: 字符串
        public static func errors(_ n: Int) -> String { Localized.trf("errorsCount", table: t, n) }

        /// warnings
        /// - Parameter n: n
        /// - Returns: 字符串
        public static func warnings(_ n: Int) -> String { Localized.trf("warningsCount", table: t, n) }

        /// tips
        /// - Parameter n: n
        /// - Returns: 字符串
        public static func tips(_ n: Int) -> String { Localized.trf("tipsCount", table: t, n) }

        /// aiFixSuggestion
        /// - Parameter s: s
        /// - Returns: 字符串
        public static func aiFixSuggestion(_ s: String) -> String { Localized.trf("aiFixSuggestion", table: t, s) }
        public static var aiFixSuggestionShort: String { tr("aiFixSuggestionShort") }

        /// aiSuggestionError
        /// - Parameter s: s
        /// - Returns: 字符串
        public static func aiSuggestionError(_ s: String) -> String { Localized.trf("aiSuggestionError", table: t, s) }
    }
}

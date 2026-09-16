//
//  L10n+Shortcuts.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Shortcuts 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public struct Shortcuts: L10nTableEntry {
        public static let tableName = "System"
        public static var t: String { tableName }

        public struct Capture {
            public static var title: String { tr("shortcuts.capture.title") }
            public static var titleResource: LocalizedStringResource { .init("shortcuts.capture.title", table: "System") }
            
            public static var description: String { tr("shortcuts.capture.description") }
            public static var descriptionResource: LocalizedStringResource { .init("shortcuts.capture.description", table: "System") }
            
            public static var contentTitle: String { tr("shortcuts.capture.contentTitle") }
            public static var contentTitleResource: LocalizedStringResource { .init("shortcuts.capture.contentTitle", table: "System") }
            
            public static var logMessage: String { tr("shortcuts.capture.logMessage") }

            /// pageTitle
            /// - Parameter summary: summary
            /// - Returns: 字符串
            public static func pageTitle(_ summary: String) -> String { trf("shortcuts.capture.pageTitle", summary) }
            public static var success: String { tr("shortcuts.capture.success") }
        }
        
        public struct Search {
            public static var title: String { tr("shortcuts.search.title") }
            public static var titleResource: LocalizedStringResource { .init("shortcuts.search.title", table: "System") }
            
            public static var description: String { tr("shortcuts.search.description") }
            public static var descriptionResource: LocalizedStringResource { .init("shortcuts.search.description", table: "System") }
            
            public static var queryTitle: String { tr("shortcuts.search.queryTitle") }
            public static var queryTitleResource: LocalizedStringResource { .init("shortcuts.search.queryTitle", table: "System") }
            
            public static var logMessage: String { tr("shortcuts.search.logMessage") }

            /// success
            /// - Parameter query: query
            /// - Returns: 字符串
            public static func success(_ query: String) -> String { trf("shortcuts.search.success", query) }
        }
        
        public struct Stats {
            public static var title: String { tr("shortcuts.stats.title") }
            public static var titleResource: LocalizedStringResource { .init("shortcuts.stats.title", table: "System") }
            
            public static var description: String { tr("shortcuts.stats.description") }
            public static var descriptionResource: LocalizedStringResource { .init("shortcuts.stats.description", table: "System") }
            
            /// success
            /// - Parameter count: 计数
            /// - Returns: 字符串
            public static func success(_ count: Int) -> String { trf("shortcuts.stats.success", count) }
        }
        
        public struct Provider {
            public static var capturePhrases1: String { tr("shortcuts.provider.capturePhrases1") }
            public static var capturePhrases2: String { tr("shortcuts.provider.capturePhrases2") }
            public static var captureShortTitle: String { tr("shortcuts.provider.captureShortTitle") }
            public static var captureShortTitleResource: LocalizedStringResource { .init("shortcuts.provider.captureShortTitle", table: "System") }
            
            public static var searchPhrases1: String { tr("shortcuts.provider.searchPhrases1") }
            public static var searchPhrases2: String { tr("shortcuts.provider.searchPhrases2") }
            public static var searchShortTitle: String { tr("shortcuts.provider.searchShortTitle") }
            public static var searchShortTitleResource: LocalizedStringResource { .init("shortcuts.provider.searchShortTitle", table: "System") }
            
            public static var statsPhrases1: String { tr("shortcuts.provider.statsPhrases1") }
            public static var statsPhrases2: String { tr("shortcuts.provider.statsPhrases2") }
            public static var statsShortTitle: String { tr("shortcuts.provider.statsShortTitle") }
            public static var statsShortTitleResource: LocalizedStringResource { .init("shortcuts.provider.statsShortTitle", table: "System") }
        }
    }
}

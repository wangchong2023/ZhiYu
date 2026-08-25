//
//  L10n+Search.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Search 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public enum Search: L10nTableEntry {
        public static let tableName = "Common"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        /// 本地化格式化翻译
        /// - Parameter key: key
        /// - Parameter args: args
        /// - Returns: 返回值
        public static var base: String { Search.tr("components.search") }
        public static var title: String { Search.tr("components.search") }
        public static var all: String { Search.tr("search.all") }
        public static var noResults: String { Search.tr("search.noResults") }
        public static var noResultsHint: String { Search.tr("search.noResultsHint") }
        public static var filterTags: String { Search.tr("search.filterTags") }

        /// results计数
        /// - Parameter count: 计数
        /// - Returns: 字符串
        public static func resultsCount(_ count: Int) -> String { Search.trf("search.resultsCount", count) }

        /// pages计数
        /// - Parameter count: 计数
        /// - Returns: 字符串
        public static func pagesCount(_ count: Int) -> String { Search.trf("search.pagesCount", count) }

        public static var Diagnostics: String { diagnostics }
        public static var diagnostics: String { Search.tr("search.diagnostics") }

        public enum Diag {
            public static var title: String { Search.tr("search.diag.title") }
            public static var rewrite: String { Search.tr("search.diag.rewrite") }
            public static var originalQuery: String { Search.tr("search.diag.originalQuery") }
            public static var rewrittenQuery: String { Search.tr("search.diag.rewrittenQuery") }
            public static var rrfDetail: String { Search.tr("search.diag.rrfDetail") }
            public static var ftsRank: String { Search.tr("search.diag.ftsRank") }
            public static var vectorRank: String { Search.tr("search.diag.vectorRank") }
            public static var miss: String { Search.tr("search.diag.miss") }
            public static var scoreFormat: String { Search.tr("search.diag.scoreFormat") }
            public static var ftsEngine: String { Search.tr("search.diag.ftsEngine") }
            public static var vectorEngine: String { Search.tr("search.diag.vectorEngine") }
            public static var ftsPrefix: String { Search.tr("search.diag.ftsPrefix") }
            public static var vecPrefix: String { Search.tr("search.diag.vecPrefix") }
        }
    }
}

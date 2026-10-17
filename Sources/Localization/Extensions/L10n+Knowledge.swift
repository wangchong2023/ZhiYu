//
//  L10n+Knowledge.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Knowledge 模块提供本地化强类型字符串的访问扩展。
//
import Foundation
import UFPCore

extension L10n {
    public enum Knowledge: L10nTableEntry {
        public static let tableName = "Knowledge"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        /// 本地化格式化翻译
        /// - Parameter key: key
        /// - Parameter args: args
        /// - Returns: 返回值
        public enum Page {
                public static var title: String { Knowledge.tr("page.source.title") }
            public static var edit: String { Knowledge.tr("page.edit") }
            public static var doneEditing: String { Knowledge.tr("page.doneEditing") }
            public static var deletePage: String { Knowledge.tr("page.deletePage") }
            public static var delete: String { Knowledge.tr("page.deletePage") }
            public static var confirmDelete: String { Knowledge.tr("page.confirmDelete") }
            public static var deleteMessage: String { Knowledge.tr("page.deleteMessage") }
            public static func batchDeleteTitle(_ count: Int) -> String { Knowledge.trf("page.batchDeleteTitle", count) }
            public static func batchDeleteMessage(_ count: Int) -> String { Knowledge.trf("page.batchDeleteMessage", count) }
            public static var icon: String { Knowledge.tr("page.icon") }
            public static var knowledge: String { Knowledge.tr("page.knowledge") }
            public static var empty: String { Knowledge.tr("page.empty") }
            public static var emptyHint: String { Knowledge.tr("page.emptyHint") }
            public static var content: String { Knowledge.tr("page.content") }
            public static var status: String { Knowledge.tr("page.status") }
            public static var metaInfo: String { Knowledge.tr("page.metaInfo") }
            public static var expandStub: String { Knowledge.tr("page.expandStub") }
            public static var findLinks: String { Knowledge.tr("page.findLinks") }
            public static var pin: String { Knowledge.tr("page.pin") }
            public static var unpin: String { Knowledge.tr("page.unpin") }
            public static var wordCountUnit: String { L10n.Common.tr("perf.summary.words") }
            public static var outLinkUnit: String { Knowledge.tr("page.outLinkUnit") }
            public static var noBackLinks: String { Knowledge.tr("page.noBackLinks") }
            public static var sourceCitation: String { L10n.Common.tr("type.source") }
            public static var sourceOpenLink: String { Knowledge.tr("page.sourceOpenLink") }
            public static var sourceTypeFile: String { L10n.Common.tr("search.sort.type") }
            public static var doubleTapToNavigate: String { Knowledge.tr("page.doubleTapToNavigate") }
            public static var backlinks: String { Knowledge.tr("page.backlinks") }
            /// 引用外部
            public static var outgoings: String { Knowledge.tr("page.outgoings") }
            /// 失效链接
            public static var brokenLinks: String { Knowledge.tr("page.brokenLinks") }
            /// 无引页面
            public static var orphanPages: String { Knowledge.tr("page.orphanPages") }

            /// 删除PageTitle
            /// - Parameter name: name
            /// - Returns: 字符串
            public static func deletePageTitle(_ name: String) -> String { Knowledge.trf("page.deletePageTitle", name) }

            /// backlinkAccessibility
            /// - Parameter title: title
            /// - Parameter type: type
            /// - Returns: 字符串
            public static func backlinkAccessibility(_ title: String, _ type: String) -> String { Knowledge.trf("page.backlinkAccessibility", title, type) }

            /// titleAccessibility
            /// - Parameter title: title
            /// - Returns: 字符串
            public static func titleAccessibility(_ title: String) -> String { Knowledge.trf("page.titleAccessibility", title) }

            /// createdAt格式化
            /// - Parameter date: date
            /// - Returns: 字符串
            public static func createdAtFormat(_ date: String) -> String { Knowledge.trf("page.createdAtFormat", date) }

            /// updatedAt格式化
            /// - Parameter date: date
            /// - Returns: 字符串
            public static func updatedAtFormat(_ date: String) -> String { Knowledge.trf("page.updatedAtFormat", date) }

            /// word计数
            /// - Parameter count: 计数
            /// - Returns: 字符串
            public static func wordCount(_ count: Int) -> String { Knowledge.trf("page.wordCount", count) }

            /// outLinks计数
            /// - Parameter count: 计数
            /// - Returns: 字符串
            public static func outLinksCount(_ count: Int) -> String { Knowledge.trf("page.outLinksCount", count) }

            /// metaAccessibility
            /// - Parameter date: date
            /// - Parameter words: words
            /// - Parameter links: links
            /// - Returns: 字符串
            public static func metaAccessibility(_ date: String, _ words: Int, _ links: Int) -> String { Knowledge.trf("page.metaAccessibility", date, words, links) }

            /// pageTypeAccessibility
            /// - Parameter type: type
            /// - Returns: 字符串
            public static func pageTypeAccessibility(_ type: String) -> String { Knowledge.trf("page.pageTypeAccessibility", type) }

            /// statusAccessibility
            /// - Parameter status: status
            /// - Returns: 字符串
            public static func statusAccessibility(_ status: String) -> String { Knowledge.trf("page.statusAccessibility", status) }

            /// confidenceAccessibility
            /// - Parameter confidence: confidence
            /// - Returns: 字符串
            public static func confidenceAccessibility(_ confidence: String) -> String { Knowledge.trf("page.confidenceAccessibility", confidence) }

            public struct AIInsightsVal {
                public let title: String
            }
            public static var aiInsights: AIInsightsVal { AIInsightsVal(title: Knowledge.tr("page.aiInsights")) }

            public enum Source {
                public static var title: String { Knowledge.tr("page.source.title") }
                public static var open: String { Knowledge.tr("page.source.open") }
                public static var content: String { Knowledge.tr("page.source.content") }
                public static var empty: String { Knowledge.tr("page.source.empty") }
                public static var copied: String { Knowledge.tr("page.source.copied") }
                public static var copyPath: String { Knowledge.tr("page.source.copyPath") }
                public static var localFile: String { Knowledge.tr("page.source.localFile") }
            }

            public enum AI {
                public static var insights: String { Knowledge.tr("page.aiInsights") }
                public static var insightsDesc: String { Knowledge.tr("page.aiInsights.desc") }
                public static var summary: String { Knowledge.tr("page.ai.summary") }
                public static var extractActions: String { Knowledge.tr("page.ai.extractActions") }
                public static var mindmap: String { Knowledge.tr("page.ai.mindmap") }
                public static var quiz: String { Knowledge.tr("page.ai.quiz") }
                public static var slides: String { Knowledge.tr("page.ai.slides") }
                public static var report: String { Knowledge.tr("page.ai.report") }
                public static var infographic: String { Knowledge.tr("page.ai.infographic") }
                public static var lab: String { Knowledge.tr("page.ai.lab") }
                public static var expansion: String { Knowledge.tr("page.ai.expansion") }
                public static var labOutput: String { Knowledge.tr("page.ai.labOutput") }
                public static var potentialLinksScanning: String { Knowledge.tr("page.ai.potentialLinksScanning") }
                public static var potentialLinksTitle: String { Knowledge.tr("page.ai.potentialLinksTitle") }
                public static var potentialLinksEmpty: String { Knowledge.tr("page.ai.potentialLinksEmpty") }
            }

            public enum History {
                public static var title: String { Knowledge.tr("page.history") }
                public static var none: String { Knowledge.tr("page.history.none") }
                public static var manual: String { Knowledge.tr("page.history.manual") }
                public static var physical: String { Knowledge.tr("page.history.physical") }
                public static var version: String { Knowledge.tr("page.history.version") }
                public static var rollback: String { Knowledge.tr("page.history.rollback") }
            }

            public enum Snapshot {
                public static var preview: String { Knowledge.tr("page.snapshot.preview") }
            }
        }
    }
}

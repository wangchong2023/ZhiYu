//
//  L10n+Plugin.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Plugin 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public enum Plugin: L10nTableEntry {
        public static let tableName = "Plugin"
        public static var t: String { tableName }
        // MARK: - 通用
        public static var title: String { Plugin.tr("plugin.center") }

        /// permTitle — 全显式 case，杜绝动态拼接，所有 key 都可被静态分析检测
        /// - Returns: 本地化权限名称
        public static func permTitle(for perm: String) -> String {
            switch perm {
            case "writeContent", "content":
                return Localized.tr("plugin.perm.content", table: t)
            case "readContent":
                return Localized.tr("plugin.perm.readContent", table: t)
            case "network":
                return L10n.Common.tr("tags.network")
            case "aiAccess":
                return Localized.tr("plugin.perm.aiAccess", table: t)
            case "log":
                return Localized.tr("plugin.perm.log", table: t)
            case "sandbox":
                return Localized.tr("plugin.perm.sandbox", table: t)
            default:
                // 未知权限：直接回退展示原始标识，不再动态拼接
                return perm
            }
        }

        /// permDesc — 全显式 case，禁止 default 分支动态构造 key
        /// - Returns: 权限详细说明
        public static func permDesc(for perm: String) -> String {
            switch perm {
            case "writeContent", "content":
                return Plugin.tr("plugin.perm.content.desc")
            case "readContent":
                return Plugin.tr("plugin.perm.readContent.desc")
            case "network":
                return Plugin.tr("plugin.perm.network.desc")
            case "aiAccess":
                return Plugin.tr("plugin.perm.aiAccess.desc")
            case "log":
                return Plugin.tr("plugin.perm.log.desc")
            case "sandbox":
                return Plugin.tr("plugin.perm.sandbox.desc")
            default:
                return Plugin.trf("plugin.perm.unknown.desc", perm)
            }
        }

        public static var centerTitle: String { tr("plugin.center") }
        public static var marketTitle: String { tr("plugin.market") }
        public static var myPlugins: String { tr("plugin.myPlugins") }
        public static var safeModeTitle: String { tr("plugin.safeMode") }
        public static var safeModeWarningTitle: String { tr("plugin.safeMode.warning.title") }
        public static var safeModeWarningMessage: String { tr("plugin.safeMode.warning.message") }
        public static var safeModeTurnOff: String { tr("plugin.safeMode.turnOff") }
        public static var searchPlaceholder: String { tr("plugin.searchPlaceholder") }
        public static var noPlugins: String { tr("plugin.noPlugins") }
        public static var noPluginsHint: String { tr("plugin.noPluginsHint") }
        public static var noResults: String { tr("plugin.noResults") }
        public static var noResultsHint: String { tr("plugin.noResultsHint") }

        /// permissionMessage
        /// - Parameter name: name
        /// - Returns: 字符串
        public static func permissionMessage(_ name: String) -> String { trf("plugin.permission.message", name) }

        public enum Sidebar {
            public static var currentSources: String { Plugin.tr("sidebar.currentSources") }
        }
        
        public typealias Section = section
        public enum section {
            public static var rag: String { Plugin.tr("section.rag") }
            public static var pluginSettings: String { Plugin.tr("section.pluginSettings") }
            public static var permissions: String { Plugin.tr("plugin.section.permissions") }
            public static var about: String { Plugin.tr("plugin.section.about") }
            public static var ribbon: String { Plugin.tr("plugin.section.ribbon") }
        }

        public enum Status {
            public static var enabled: String { Plugin.tr("plugin.status.enabled") }
            public static var disabled: String { Plugin.tr("plugin.status.disabled") }
        }

        public enum market {
            public static var empty: String { Plugin.tr("plugin.market.empty") }
            public static var emptyHint: String { Plugin.tr("plugin.market.emptyHint") }
            public static var connectionError: String { Plugin.tr("plugin.market.connectionError") }
        }

        public enum commands {
            public static var title: String { Plugin.tr("plugin.commands.title") }
        }

        public enum local {
            public static var mount: String { Plugin.tr("plugin.local.mount") }
            public static var desc: String { Plugin.tr("plugin.local.desc") }
        }

        public enum Stats {
            public static var downloads: String { Plugin.tr("plugin.stats.downloads") }
            public static var rating: String { Plugin.tr("plugin.stat.rating") }
            public static var resourceUsage: String { Plugin.tr("plugin.stats.resourceUsage") }
            public static var noUsage: String { Plugin.tr("plugin.stats.noUsage") }
            public static var enabledCount: String { Plugin.tr("plugin.stats.enabledCount") }
            public static var activeCount: String { Plugin.tr("plugin.stats.activeCount") }
            public static var cpu: String { Plugin.tr("plugin.stats.cpu") }
            public static var ratio: String { Plugin.tr("plugin.stats.ratio") }

            /// call计数格式化
            /// - Parameter calls: calls
            /// - Parameter avgMs: avgMs
            /// - Returns: 字符串
            public static func callCountFormat(calls: Int, avgMs: Double) -> String {
                Plugin.trf("plugin.stats.callCountFormat", calls, avgMs)
            }
            public static func totalExecutionTime(_ val: String) -> String {
                Plugin.trf("plugin.stats.totalExecutionTime", val)
            }
        }

        public enum Category {
            public static var all: String { Plugin.tr("plugin.category.all") }
            public static var efficiency: String { L10n.Common.tr("tags.efficiency") }
            public static var social: String { Plugin.tr("plugin.category.social") }
            public static var reading: String { Plugin.tr("plugin.category.reading") }
            public static var other: String { Plugin.tr("plugin.category.other") }
        }

        public static var noPluginsInCategory: String { tr("plugin.noPluginsInCategory") }
        public static var noPluginsInCategoryHint: String { tr("plugin.noPluginsInCategoryHint") }

        public enum settings {
            public static var noSettings: String { Plugin.tr("plugin.settings.noSettings") }
        }

        public enum Action {
            public static var install: String { Plugin.tr("plugin.action.install") }
            public static var uninstall: String { Plugin.tr("plugin.action.uninstall") }
            public static var confirmInstall: String { Plugin.tr("plugin.action.confirmInstall") }
        }

        public enum perm {
            public static var none: String { Plugin.tr("plugin.perm.none") }
        }

        public enum permission {
            public static var title: String { Plugin.tr("plugin.permission.title") }

            /// message
            /// - Parameter name: name
            /// - Returns: 字符串
            public static func message(_ name: String) -> String { Plugin.trf("plugin.permission.message", name) }
        }

        // MARK: - 沙盒与 DLP 安全拦截报错词条
        // MARK: - 插件详情页（参照业界标准）

        public enum Detail {
            /// "by {author}"
            public static func byAuthor(_ author: String) -> String { Plugin.trf("plugin.detail.byAuthor", author) }
            public static var downloadsUnit: String { Plugin.tr("plugin.detail.downloadsUnit") }
            public static var installed: String { Plugin.tr("plugin.detail.installed") }
            public static var metadataTitle: String { Plugin.tr("plugin.detail.metadata") }
            public static var version: String { Plugin.tr("plugin.detail.version") }
            public static var author: String { Plugin.tr("plugin.detail.author") }
            public static var minAppVersion: String { Plugin.tr("plugin.detail.minAppVersion") }
            public static var category: String { Plugin.tr("plugin.detail.category") }
            public static var license: String { Plugin.tr("plugin.detail.license") }
            public static var reportTitle: String { Plugin.tr("plugin.detail.report") }
            public static var reportIssue: String { Plugin.tr("plugin.detail.reportIssue") }
            public static var viewSource: String { Plugin.tr("plugin.detail.viewSource") }
            public static var categoryLocal: String { Plugin.tr("plugin.detail.category.local") }
            public static var categoryRemote: String { Plugin.tr("plugin.detail.category.remote") }
            public static var categoryCommunity: String { Plugin.tr("plugin.detail.category.community") }
            public static var licenseFree: String { Plugin.tr("plugin.detail.license.free") }
            public static var licenseDonation: String { Plugin.tr("plugin.detail.license.donation") }
            public static var licenseSubscription: String { Plugin.tr("plugin.detail.license.subscription") }

            /// 评价数格式化，如 "（287）"
            public static func reviewCount(_ count: Int) -> String { Plugin.trf("plugin.detail.reviewCount", count) }
            
            public static var readMore: String { Plugin.tr("plugin.detail.readMore") }
            public static var showLess: String { Plugin.tr("plugin.detail.showLess") }
            public static var ratingsTitle: String { Plugin.tr("plugin.detail.ratings") }
            public static var secureLabel: String { Plugin.tr("plugin.detail.secure") }
            public static var securePassed: String { Plugin.tr("plugin.detail.securePassed") }
            public static var allPlatforms: String { Plugin.tr("plugin.detail.allPlatforms") }
            public static var compatibilityTitle: String { Plugin.tr("plugin.detail.compatibility") }
        }

        public enum Error {
            public static var sandboxBlocked: String { Plugin.tr("plugin.error.sandboxBlocked") }
            public static var dlpScriptBlocked: String { Plugin.tr("plugin.error.dlpScriptBlocked") }

            /// dlp拉取Blocked
            /// - Parameter host: host
            /// - Returns: 字符串
            public static func dlpFetchBlocked(_ host: String) -> String { Plugin.trf("plugin.error.dlpFetchBlocked", host) }

            /// pre处理Exception
            /// - Parameter reason: reason
            /// - Returns: 字符串
            public static func preProcessException(_ reason: String) -> String { Plugin.trf("plugin.error.preProcessException", reason) }
            public static var payloadTooLarge: String { Plugin.tr("plugin.error.payloadTooLarge") }

            /// post处理Exception
            /// - Parameter reason: reason
            /// - Returns: 字符串
            public static func postProcessException(_ reason: String) -> String { Plugin.trf("plugin.error.postProcessException", reason) }

            /// invalidURL
            /// - Parameter url: url
            /// - Returns: 字符串
            public static func invalidURL(_ url: String) -> String { Plugin.trf("plugin.error.invalidURL", url) }

            /// keyLengthExceeded
            /// - Parameter limit: limit
            /// - Returns: 字符串
            public static func keyLengthExceeded(_ limit: Int) -> String { Plugin.trf("plugin.error.keyLengthExceeded", limit) }

            /// permissionDenied
            /// - Parameter permission: permission
            /// - Returns: 字符串
            public static func permissionDenied(_ permission: String) -> String { Plugin.trf("plugin.error.permissionDenied", permission) }
        }
    }
}

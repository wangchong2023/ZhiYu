//
//  L10n+Action.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Action 模块提供本地化强类型字符串的访问扩展。
//
import Foundation
import UFPCore

extension L10n {
    public struct Action: L10nTableEntry {
        public static let tableName = "Common"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        public static var createPage: String { tr("action.createPage") }
        public static var createPageSubtitle: String { tr("action.createPageSubtitle") }
        public static var ingestKnowledge: String { tr("action.ingestKnowledge") }
        public static var ingestKnowledgeSubtitle: String { tr("action.ingestKnowledgeSubtitle") }

        public struct cmd {
            public static var deepExplore: String { Localized.tr("action.cmd.deepExplore", table: t) }
            public static var newKnowledgePage: String { Localized.tr("action.cmd.newKnowledgePage", table: t) }
            public static var quickActions: String { Localized.tr("action.cmd.quickActions", table: t) }
            public static var recentAccess: String { Localized.tr("action.cmd.recentAccess", table: t) }
        }
    }
}

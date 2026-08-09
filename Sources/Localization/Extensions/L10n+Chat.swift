//
//  L10n+Chat.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Chat 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public struct Chat: L10nTableEntry {
        public static let tableName = "AI"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        /// 获取活跃会话个数文案
        /// - Parameter count: 会话个数
        /// - Returns: 本地化格式化文案
        public static func activeSessionCount(_ count: Int) -> String { Localized.trf("chat.activeSessionCount", table: t, count) }

        /// 获取消息条数文案
        /// - Parameter count: 消息条数
        /// - Returns: 本地化格式化文案
        public static func messageCount(_ count: Int) -> String { Localized.trf("chat.messageCount", table: t, count) }

        /// 获取消耗 Token 数文案
        /// - Parameter count: Token数
        /// - Returns: 本地化格式化文案
        public static func tokenUsage(_ count: Int) -> String { Localized.trf("chat.tokenUsage", table: t, count) }

        /// 获取引用文献个数文案
        /// - Parameter count: 引用文献个数
        /// - Returns: 本地化格式化文案
        public static func referenceCount(_ count: Int) -> String { Localized.trf("chat.referenceCount", table: t, count) }

        /// 获取上下文超限警告文案
        /// - Parameter limit: 限制数
        /// - Returns: 本地化格式化文案
        public static func contextLimitWarning(_ limit: Int) -> String { Localized.trf("chat.contextLimitWarning", table: t, limit) }

        public static var title: String { tr("chat.title") }
        public static var welcomeDesc: String { tr("chat.welcomeDesc") }

        public struct group {
            public static var ai: String { Chat.tr("chat.group.ai") }
            public static var base: String { Chat.tr("chat.group.base") }
            public static var user: String { Chat.tr("chat.group.user") }
        }

        public static var aiAssistantName: String { tr("chat.aiAssistantName") }
        public static var referencesExpanded: String { tr("chat.referencesCollapsed") }
        public static var referencesCollapsed: String { tr("chat.referencesCollapsed") }
        public static var clearHistoryConfirmTitle: String { tr("chat.clearHistory.confirm.title") }
        public static var clearHistoryConfirmMessage: String { tr("chat.clearHistory.confirm.message") }
        public static var configureFirst: String { tr("chat.configureFirst") }
        public static var aiRunning: String { tr("chat.aiRunning") }
        public static var inputPlaceholder: String { tr("chat.inputPlaceholder") }
        public static var explorationAndPrompts: String { tr("chat.explorationAndPrompts") }
        public static var exportConversation: String { tr("chat.exportConversation") }
        public static var exportRoleUser: String { tr("chat.exportRoleUser") }
        public static var exportRoleAI: String { tr("chat.exportRoleAI") }
        public static var exportFileName: String { tr("chat.exportFileName") }
        public static var llmSettings: String { tr("chat.llmSettings") }
        public static var selectToExport: String { tr("chat.selectToExport") }
        public static var exportSelectedPDF: String { tr("chat.exportSelectedPDF") }
        public static var exportPDF: String { tr("chat.exportPDF") }

        /// 获取深度探索/总体探索的提示词文案
        /// - Parameter topic: 探索主题
        /// - Returns: 本地化格式化文案
        public static func deepExplorePrompt(_ topic: String) -> String { Localized.trf("chat.deepExplorePrompt", table: t, topic) }

        public struct ai {
            public static var thinking: String { Chat.tr("chat.ai.thinking") }
        }

        /// AI 增强型骨架屏状态本地化定义
        public struct skeleton {
            /// 正在思考
            public static var thinking: String { Chat.tr("ai.status.skeleton.thinking") }
            /// 正在初始化神经网络权重
            public static var embedding: String { Chat.tr("ai.status.skeleton.embedding") }
            /// 正在扫描本地知识库
            public static var retrieval: String { Chat.tr("ai.status.skeleton.retrieval") }
            /// 正在合成核心概念
            public static var synthesis: String { Chat.tr("ai.status.skeleton.synthesis") }
        }

        /// 重新生成最后一次回复
        public static var regenerate: String { Chat.tr("action.regenerate") }

        /// 已复制到剪切板
        public static var copied: String { Chat.tr("chat.copied") }
    }
}

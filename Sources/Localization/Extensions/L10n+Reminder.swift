//
//  L10n+Reminder.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Reminder 模块提供本地化强类型字符串的访问扩展。
//
import Foundation
import UFPCore

extension L10n {
    /// 提醒事项服务多语言强类型扩展
    public enum Reminder: L10nTableEntry {
        public static let tableName = "System"        
        public static var t: String { tableName }
        /// 获取带表名映射的翻译
        /// - Parameter key: 多语言键值
        /// - Returns: 翻译文案
        /// 找不到可用的提醒事项列表错误提示
        public static var noListAvailableMessage: String { tr("reminder.noListAvailableMessage") }
    }
}

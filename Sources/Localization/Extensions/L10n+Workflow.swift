//
//  L10n+Workflow.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Workflow 模块提供本地化强类型字符串的访问扩展。
//
import Foundation
import UFPCore

extension L10n {
    /// 工作流服务多语言强类型扩展
    public enum Workflow: L10nTableEntry {
        public static let tableName = "System"        
        public static var t: String { tableName }
        /// 获取带表名映射的翻译
        /// - Parameter key: 多语言键值
        /// - Returns: 翻译文案
        /// 获取带参数的格式化翻译
        /// - Parameters:
        ///   - key: 多语言键值
        ///   - args: 参数列表
        /// - Returns: 格式化后的翻译文案
        /// 无法访问提醒事项时的错误信息
        public static var accessDeniedMessage: String { tr("workflow.accessDeniedMessage") }
        
        /// 未发现可同步事项时的提示信息
        public static var noTasksFoundMessage: String { tr("workflow.noTasksFoundMessage") }
        
        /// 正在同步中提示
        /// - Parameter count: 同步条数
        /// - Returns: 格式化文案
        public static func syncingMessage(_ count: Int) -> String { trf("workflow.syncingMessage", count) }
        
        /// 同步来源前缀
        /// - Parameter title: 知识页面标题
        /// - Returns: 格式化文案
        public static func sourceNotes(_ title: String) -> String { trf("workflow.sourceNotes", title) }
        
        /// 同步成功提示
        /// - Parameter count: 同步条数
        /// - Returns: 格式化文案
        public static func syncSuccessMessage(_ count: Int) -> String { trf("workflow.syncSuccessMessage", count) }
        
        /// 同步失败错误提示
        /// - Parameter details: 错误详情
        /// - Returns: 格式化文案
        public static func syncErrorMessage(_ details: String) -> String { trf("workflow.syncErrorMessage", details) }
    }
}

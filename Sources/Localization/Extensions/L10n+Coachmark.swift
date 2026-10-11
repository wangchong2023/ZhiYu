//
//  L10n+Coachmark.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Coachmark 模块提供本地化强类型字符串的访问扩展。
//
import Foundation
import UFPCore

extension L10n {
    public struct Coachmark: L10nTableEntry {
        public static let tableName = "System"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        /// 引导对话框：发现隐藏关联标题
        public static var graphDiscoveryTitle: String { tr("coachmark.graphDiscovery.title") }

        /// 引导对话框：发现隐藏关联描述信息
        public static var graphDiscoveryDesc: String { tr("coachmark.graphDiscovery.desc") }

        /// 引导对话框：发现隐藏关联动作按钮文字
        public static var graphDiscoveryAction: String { tr("coachmark.graphDiscovery.action") }
    }
}

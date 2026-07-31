//
//  L10n+Accessibility.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Accessibility 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public struct Accessibility: L10nTableEntry, Sendable {
        public static let tableName = "Common"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        /// 标签的无障碍声明
        public static var tags: String { Localized.tr("accessibility.tags", table: t) }
        /// 字数的无障碍声明
        public static var words: String { Localized.tr("accessibility.words", table: t) }
        /// 链接的无障碍声明
        public static var links: String { Localized.tr("accessibility.links", table: t) }
        /// 打开操作的无障碍基础声明
        public static var tapToOpen: String { Localized.tr("accessibility.tapToOpen", table: t) }
        
        /// 笔记本笔记本卡片的无障碍类别标签
        public static var notebookCardLabel: String { Localized.tr("accessibility.notebookCardLabel", table: t) }
        /// 笔记本笔记本卡片无障碍手势提示文案
        public static var notebookCardHint: String { Localized.tr("accessibility.notebookCardHint", table: t) }
        /// 列表单行笔记本无障碍手势提示文案
        public static var notebookListRowHint: String { Localized.tr("accessibility.notebookListRowHint", table: t) }
    }
}

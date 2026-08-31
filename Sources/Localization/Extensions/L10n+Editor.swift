//
//  L10n+Editor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Editor 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public struct Editor: L10nTableEntry {
        public static let tableName = "Knowledge"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        public static var insertPageLink: String { Localized.tr("editor.insertPageLink", table: t) }
        public static var searchPages: String { Localized.tr("editor.searchPages", table: t) }
        public static var bidirectionalLinks: String { Localized.tr("editor.bidirectionalLinks", table: t) }
        public static var enterTag: String { Localized.tr("editor.enterTag", table: t) }
        public static var addTag: String { Localized.tr("editor.addTag", table: t) }
        public static var tableColumn1: String { Localized.tr("editor.tableColumn1", table: t) }
        public static var tableColumn2: String { Localized.tr("editor.tableColumn2", table: t) }
        public static var tableColumn3: String { Localized.tr("editor.tableColumn3", table: t) }
        public static var tableContent: String { Localized.tr("create.content", table: t) }
        public static var bold: String { Localized.tr("editor.bold", table: t) }
        public static var code: String { Localized.tr("editor.code", table: t) }
        public static var divider: String { Localized.tr("editor.divider", table: t) }
        public static var italic: String { Localized.tr("editor.italic", table: t) }
        public static var knowledgeLink: String { Localized.tr("editor.knowledgeLink", table: t) }
        public static var link: String { Localized.tr("editor.link", table: t) }
        public static var list: String { Localized.tr("editor.list", table: t) }
        public static var ocrScan: String { Localized.tr("editor.ocrScan", table: t) }
        public static var quote: String { Localized.tr("editor.quote", table: t) }
        public static var table: String { Localized.tr("editor.table", table: t) }
        public static var selectedText: String { Localized.tr("editor.selectedText", table: t) }
        public static var placeholder: String { Localized.tr("editor.placeholder", table: t) }
        public static var toc: String { Localized.tr("editor.toc", table: t) }
        public static var outline: String { Localized.tr("editor.outline", table: t) }

        public struct iconPicker {
            public static var customSelected: String { Localized.tr("editor.iconPicker.customSelected", table: t) }
            public static var useDefault: String { Localized.tr("editor.iconPicker.useDefault", table: t) }
            public static var selectIcon: String { Localized.tr("editor.iconPicker.selectIcon", table: t) }
            // Bug #100 修复：图标分类名称强类型化，禁止动态 tr(key) 调用
            public static var common: String { Localized.tr("editor.iconPicker.common", table: t) }
            public static var academic: String { Localized.tr("editor.iconPicker.academic", table: t) }
            public static var nature: String { Localized.tr("editor.iconPicker.nature", table: t) }
            public static var transport: String { Localized.tr("editor.iconPicker.transport", table: t) }
            public static var symbols: String { Localized.tr("editor.iconPicker.symbols", table: t) }
        }
    }
}

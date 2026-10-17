//
//  L10n+Tag.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Tag 模块提供本地化强类型字符串的访问扩展。
//
import Foundation
import UFPCore

extension L10n {
    public enum Tag: L10nTableEntry {
        public static let tableName = "Knowledge"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        /// 本地化格式化翻译
        /// - Parameter key: key
        /// - Parameter args: args
        /// - Returns: 返回值
        public static var title: String { tr("tag.title") }
        public static var allTags: String { tr("tag.allTags") }
        public static var relatedPagesTitle: String { tr("create.template.entity.related") }
        public static func tagCount(_ n: Int) -> String { trf("tag.count", n) }
        public static var layoutList: String { Tag.tr("editor.list") }
        public static var layoutBubble: String { Tag.tr("tag.layoutBubble") }
        public static var expandAll: String { Tag.tr("tag.expandAll") }
        public static var collapse: String { Tag.tr("tag.collapse") }

        public enum Action {
            public static var rename: String { L10n.Common.rename }
            public static var delete: String { L10n.Common.delete }
            public static var renameTag: String { Tag.tr("tag.renameTag") }
            public static var newName: String { Tag.tr("tag.newName") }
            public static var deleteTag: String { Tag.tr("tag.deleteTag") }
            public static var noTags: String { Tag.tr("tag.noTags") }
            public static var noTagsHint: String { Tag.tr("tag.noTagsHint") }

            /// 重命名Message
            /// - Parameter name: name
            /// - Returns: 字符串
            public static func renameMessage(_ name: String) -> String { Tag.trf("tag.renameMessage", name) }

            /// 删除Message
            /// - Parameter name: name
            /// - Returns: 字符串
            public static func deleteMessage(_ name: String) -> String { Tag.trf("tag.deleteMessage", name) }

            /// tagPages
            /// - Parameter count: 计数
            /// - Returns: 字符串
            public static func tagPages(_ count: Int) -> String { Tag.trf("tag.tagPages", count) }
        }

        public enum Management {
            public static var addNew: String { Tag.tr("tags.addNew") }
            public static var inputName: String { Tag.tr("tags.inputName") }
            public static var manageTitle: String { Tag.tr("tags.manageTitle") }
            public static var createHint: String { Tag.tr("tags.createHint") }
            public static var selectToManage: String { Tag.tr("tags.selectToManage") }

            /// bulk删除Warning
            /// - Parameter count: 计数
            /// - Returns: 字符串
            public static func bulkDeleteWarning(_ count: Int) -> String { Tag.trf("tags.bulkDeleteWarning", count) }

            /// selected计数
            /// - Parameter count: 计数
            /// - Returns: 字符串
            public static func selectedCount(_ count: Int) -> String { Tag.trf("tags.selectedCount", count) }
        }

        public enum Cloud {
            public static var selectTag: String { Tag.tr("tagcloud.selectTag") }
        }
    }
}

//
//  L10n+Schema.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Schema 模块提供本地化强类型字符串的访问扩展。
//
import Foundation
import UFPCore

extension L10n {
    public struct Schema: L10nTableEntry {
        public static let tableName = "Common" // 假设 Schema 放在 Common 表中，或者根据实际情况调整
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        public struct concept {
            public static var template: String { Schema.tr("schema.concept.template") }
            public static var prompt: String { Schema.tr("schema.concept.prompt") }
            public struct field {
                public static var applications: String { Schema.tr("schema.concept.field.applications") }
                public static var theory: String { Schema.tr("schema.concept.field.theory") }
            }
        }
        public struct entity {
            public static var template: String { Schema.tr("schema.entity.template") }
            public static var prompt: String { Schema.tr("schema.entity.prompt") }
            public struct field {
                public static var attributes: String { Schema.tr("schema.entity.field.attributes") }
                public static var definition: String { Schema.tr("schema.entity.field.definition") }
                public static var relations: String { Schema.tr("schema.entity.field.relations") }
            }
        }
    }
}

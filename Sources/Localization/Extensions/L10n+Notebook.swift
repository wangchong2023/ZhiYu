//
//  L10n+Notebook.swift
//  ZhiYu
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Notebook（笔记本）模块提供本地化强类型字符串的访问扩展，词条归属 Knowledge 表。
//
import Foundation
import UFPCore

extension L10n {
    public enum Notebook: L10nTableEntry {
        public static let tableName = "Knowledge"
        public static var t: String { tableName }

        // MARK: - 笔记本入口
        /// 打开笔记本中心
        public static var openHub: String { tr("notebook.openHub") }
    }
}

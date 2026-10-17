//
//  L10n+Backup.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Backup 模块提供本地化强类型字符串的访问扩展。
//
import Foundation
import UFPCore

extension L10n {
    public enum Backup: L10nTableEntry {
        public static let tableName = "Ingest"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        public static var title: String { tr("backup.title") }
        public static var autoBackup: String { tr("backup.autoBackup") }
        public static var createNow: String { tr("backup.createNow") }
        public static var exportCurrent: String { tr("backup.exportCurrent") }
        public static var pages: String { tr("backup.pages") }
        public static var words: String { L10n.Common.tr("perf.summary.words") }
        public static var restoreTitle: String { tr("backup.restore") }
        public static var deleteConfirmTitle: String { tr("backup.deleteConfirmTitle") }
        public static var lastBackup: String { tr("backup.lastBackup") }
        public static var restore: String { tr("backup.restore") }
        public static var restoreMessage: String { tr("backup.restoreMessage") }
        public static var settings: String { tr("backup.settings") }
        public static var actions: String { tr("backup.actions") }
        public static var noBackups: String { tr("backup.noBackups") }
        public static var noBackupsDesc: String { tr("backup.noBackupsDesc") }
        public static var deleteConfirmMessage: String { tr("backup.deleteConfirmMessage") }
        public static var history: String { tr("backup.history") }

        public enum log {
            public static var createFailed: String { tr("backup.log.createFailed") }
            public static var restoreFailed: String { tr("backup.log.restoreFailed") }
            public static var saveIndexFailed: String { tr("backup.log.saveIndexFailed") }
            public static var crashRecovery: String { tr("backup.log.crashRecovery") }
        }
    }
}

//
//  L10n+ICloud.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 ICloud 模块提供本地化强类型字符串的访问扩展。
//
import Foundation
import UFPCore

extension L10n {
    public enum ICloud: L10nTableEntry {
        public static let tableName = "Ingest"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        /// 本地化格式化翻译
        /// /// - Parameter key: key
        /// /// - Parameter args: args
        /// /// - Returns: 返回值
        public static var pushToCloud: String { tr("icloud.push") }
        public static var pullFromCloud: String { tr("icloud.pull") }
        public static var bidirectionalSync: String { tr("icloud.sync") }
        public static var clearCloudData: String { tr("icloud.clear") }
        public static var pushComplete: String { tr("icloud.push.complete") }
        public static var pullComplete: String { tr("icloud.pull.complete") }
        public static var syncComplete: String { tr("icloud.sync.complete") }
        public static var lastSync: String { tr("icloud.lastSync") }
        public static var never: String { tr("icloud.lastSync.never") }

        public enum Status {
            public static var syncing: String { ICloud.tr("icloud.status.syncing") }
            public static var uploading: String { ICloud.tr("icloud.status.uploading") }
            public static var downloading: String { ICloud.tr("icloud.status.downloading") }
            public static var upToDate: String { ICloud.tr("icloud.status.upToDate") }
            public static var error: String { ICloud.tr("icloud.status.error") }
            public static var notAvailable: String { ICloud.tr("icloud.status.notAvailable") }
        }

        public enum Error {
            public static var auth: String { ICloud.tr("icloud.error.auth") }
            public static var quota: String { ICloud.tr("icloud.error.quota") }
            public static var network: String { ICloud.tr("icloud.error.network") }
            public static var conflict: String { ICloud.tr("icloud.error.conflict") }
            public static var decoding: String { ICloud.tr("icloud.error.decoding") }
            public static var encoding: String { ICloud.tr("icloud.error.encoding") }
            public static var notAvailable: String { ICloud.tr("icloud.error.notAvailable") }
        }

        public enum Conflict {
            public static var manualMergeTitle: String { ICloud.tr("conflict.manualMerge") }
            public static var completeMerge: String { ICloud.tr("conflict.finishMerge") }
            public static var noPhysicalConflict: String { ICloud.tr("conflict.noContentConflict") }
            public static var metaConflictAutoSolved: String { ICloud.tr("conflict.autoResolveDesc") }
            public static var runSmartMerge: String { ICloud.tr("conflict.doAutoResolve") }

            /// docList计数
            /// - Parameter count: 计数
            /// - Returns: 字符串
            public static func docListCount(_ count: Int) -> String { ICloud.trf("conflict.listTitle", count) }

            /// localVersionTime
            /// - Parameter timeStr: timeStr
            /// - Returns: 字符串
            public static func localVersionTime(_ timeStr: String) -> String { ICloud.trf("conflict.localTime", timeStr) }

            /// remoteVersionTime
            /// - Parameter timeStr: timeStr
            /// - Returns: 字符串
            public static func remoteVersionTime(_ timeStr: String) -> String { ICloud.trf("conflict.cloudTime", timeStr) }
            public static var smartOverwriteMode: String { ICloud.tr("conflict.smartOverrideMode") }
            public static var allChooseLocal: String { ICloud.tr("conflict.keepLocalAll") }
            public static var allChooseRemote: String { ICloud.tr("conflict.keepCloudAll") }
            public static var localVersionHeader: String { ICloud.tr("conflict.localVersionTag") }
            public static var remoteVersionHeader: String { ICloud.tr("conflict.cloudVersionTag") }
            public static var mergedResultEditorHeader: String { ICloud.tr("conflict.editorTag") }
            public static var chooseLocalContent: String { ICloud.tr("conflict.takeLocalAction") }
            public static var chooseRemoteContent: String { ICloud.tr("conflict.takeCloudAction") }
            public static var noTimeInfo: String { ICloud.tr("conflict.noTimeInfo") }
        }
    }
}

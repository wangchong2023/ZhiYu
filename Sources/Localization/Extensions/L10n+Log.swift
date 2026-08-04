//
//  L10n+Log.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Log 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public struct Log: L10nTableEntry {
        public static let tableName = "Common"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        public static var noLogs: String { tr("log.noLogs") }
        public static var clearConfirmTitle: String { tr("log.clearConfirmTitle") }
        public static var startTime: String { tr("log.startTime") }
        public static var endTime: String { tr("log.endTime") }
        public static var duration: String { tr("log.duration") }
        public static var failureReason: String { tr("log.failureReason") }
        public static var statusSuccess: String { tr("log.statusSuccess") }
        public static var statusFailure: String { tr("log.statusFailure") }
        public static var statusProcessing: String { tr("log.statusProcessing") }
    }
}

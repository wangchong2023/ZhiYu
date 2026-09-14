//
//  L10n+Transfer.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Transfer 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public struct Transfer: L10nTableEntry {
        public static let tableName = "Ingest"
        public static var t: String { tableName }
        public struct Export: L10nTableEntry {
            public static let tableName = "Ingest"

            /// 导出引擎正忙本地化文案
            public static let errorSystemBusy = Export.tr("error.busy")
            /// 导出引擎未就绪本地化文案
            public static let errorEngineNotReady = Export.tr("error.notReady")
            /// 导出引擎发生内部异常本地化文案
            public static func errorInternal(_ msg: String) -> String {
                Export.trf("error.internalError", msg)
            }
        }
    }
}

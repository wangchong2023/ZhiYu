//
//  L10n+Platform.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为平台特定功能提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public enum Platform: L10nTableEntry {
        public static let tableName = "Platform"
        public static var t: String { tableName }
        /// 本地化翻译
        /// /// - Parameter key: key
        /// /// - Returns: 返回值
        public enum Unsupported {
            public static var pdf: String { Platform.tr("platform.unsupported.pdf") }
            public static var mermaid: String { Platform.tr("platform.unsupported.mermaid") }
        }

        public enum Watch {
            public static var pages: String { Platform.tr("watch.pages") }
            public static var words: String { Platform.tr("watch.words") }
            public static var recentUpdates: String { L10n.Common.recentUpdates }
            public static var tenThousand: String { Platform.tr("watch.tenThousand") }
        }
    }
}

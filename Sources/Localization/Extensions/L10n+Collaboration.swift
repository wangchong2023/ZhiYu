//
//  L10n+Collaboration.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Collaboration 模块提供本地化强类型字符串的访问扩展。
//
import Foundation
import UFPCore

extension L10n {
    public enum Collaboration: L10nTableEntry {
        public static let tableName = "Plugin"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        public static var title: String { tr("collab.title") }
        public static var subtitle: String { tr("collab.subtitle") }
        public static var defaultRoom: String { tr("collab.defaultRoom") }
        public static var room: String { tr("collab.room") }
        public static var roomName: String { tr("collab.roomName") }
        public static var roomNamePlaceholder: String { tr("collab.roomNamePlaceholder") }
        public static var username: String { tr("collab.username") }
        public static var usernamePlaceholder: String { tr("collab.usernamePlaceholder") }
        public static var nearbyRooms: String { tr("collab.nearbyRooms") }
        public static var howItWorks: String { tr("collab.howItWorks") }
        public static var hostedBy: String { tr("collab.hostedBy") }
        public static var noNearbyRooms: String { tr("collab.noNearbyRooms") }
        public static var joinSession: String { tr("collab.joinSession") }
        public static var hostSession: String { tr("collab.hostSession") }
        public static var startHosting: String { tr("collab.startHosting") }
        public static var hostSetup: String { tr("collab.hostSetup") }
        public static var stopSearching: String { tr("collab.stopSearching") }
        public static var searching: String { tr("collab.searching") }
        public static var leaveSession: String { tr("collab.leaveSession") }
        public static var connectedUsers: String { tr("collab.connectedUsers") }
        public static var recentEdits: String { tr("collab.recentEdits") }
        public static var noEdits: String { tr("collab.noEdits") }
        public static var simulatorWarning: String { tr("collab.simulatorWarning") }

        public enum role {
            public static var editor: String { Localized.tr("collab.role.editor", table: t) }
            public static var owner: String { Localized.tr("collab.role.owner", table: t) }
            public static var viewer: String { Localized.tr("collab.role.viewer", table: t) }
        }

        public enum Error {
            public static var connectionTimeout: String { Localized.tr("collab.error.connectionTimeout", table: t) }
            public static var noPermission: String { Localized.tr("collab.error.noPermission", table: t) }
        }

        public enum Status {
            public static let t = "Plugin"
            public static var simulatorNotSupported: String { Localized.tr("collab.status.simulatorNotSupported", table: t) }
            public static var disconnected: String { Localized.tr("collab.status.disconnected", table: t) }
            public static var connecting: String { Localized.tr("collab.status.connecting", table: t) }
            public static var hosting: String { Localized.tr("collab.status.hosting", table: t) }
            public static var joining: String { Localized.tr("collab.status.joining", table: t) }
            public static var connected: String { Localized.tr("collab.status.connected", table: t) }
            public static var searching: String { Localized.tr("collab.status.searching", table: t) }
            public static var browseError: String { Localized.tr("collab.status.browseError", table: t) }
            public static var advertiseError: String { Localized.tr("collab.status.advertiseError", table: t) }
            public static var pageReceived: String { Localized.tr("collab.status.pageReceived", table: t) }
            public static var ready: String { Localized.tr("collab.status.ready", table: t) }
        }

        public enum info {
            public static var encrypted: String { Localized.tr("collab.info.encrypted", table: t) }
            public static var maxPeers: String { Localized.tr("collab.info.maxPeers", table: t) }
            public static var local: String { Localized.tr("collab.info.local", table: t) }
        }
    }
}

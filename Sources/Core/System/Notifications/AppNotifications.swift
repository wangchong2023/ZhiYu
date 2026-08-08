//
//  AppNotifications.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：本地与远程推送通知管理。
//
import Foundation

extension Notification.Name {
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let splashDismissed = Notification.Name("splashDismissed")
    static let importFromClipboard = Notification.Name("importFromClipboard")
    static let languageChanged = Notification.Name("languageChanged")
    static let vaultWillSwitch = Notification.Name("vaultWillSwitch")
}

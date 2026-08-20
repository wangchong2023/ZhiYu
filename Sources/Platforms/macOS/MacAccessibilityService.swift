//
//  MacAccessibilityService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：属于 Platforms 模块，提供 macOS 原生平台下的无障碍 VoiceOver 宣告。
//

#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit

/// macOS 原生平台特化的 VoiceOver 语音宣告服务实现类。
public final class MacAccessibilityService: AccessibilityServiceProtocol, Sendable {
    
    /// 初始化 macOS 辅助功能服务。
    public init() {}
    
    /// 向 macOS 系统 NSAccessibility 引擎发布语音宣告。
    ///
    /// - Parameter text: 宣告文本。
    public func postAnnouncement(_ text: String) {
        // macOS AppKit 原生宣告接口
        let notification = NSAccessibility.Notification.announcementRequested
        let userInfo: [NSAccessibility.AnnouncementKey: Any] = [
            .announcement: text,
            .priority: NSAccessibility.AnnouncementPriority.high.rawValue
        ]
        NSAccessibility.post(notification: notification, argument: userInfo)
    }
}
#endif

//
//  iOSAccessibilityService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：属于 Platforms 模块，提供 iOS 及 macOS Catalyst 设备下的无障碍 VoiceOver 宣告。
//

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit

/// iOS 与 macOS Catalyst 设备平台特化的 VoiceOver 语音宣告服务实现类。
public final class iOSAccessibilityService: AccessibilityServiceProtocol, Sendable {
    
    /// 初始化 iOS 辅助功能服务。
    public init() {}
    
    /// 向 iOS 系统 VoiceOver 引擎发布 announcement 语音宣告。
    ///
    /// - Parameter text: 宣告文本。
    public func postAnnouncement(_ text: String) {
        // 使用 iOS UIKit 无障碍公告机制
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}
#endif

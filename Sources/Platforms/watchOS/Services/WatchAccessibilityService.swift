//
//  WatchAccessibilityService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：属于 Platforms 模块，提供 watchOS (Apple Watch) 表盘端的无障碍宣告。
//

#if os(watchOS)
import Foundation

/// watchOS 表盘平台特化的 VoiceOver 语音宣告服务（目前做静默空实现）。
public final class WatchAccessibilityService: AccessibilityServiceProtocol, Sendable {
    
    /// 初始化 watchOS 辅助功能服务。
    public init() {}
    
    /// 向 watchOS 系统 VoiceOver 引擎发布语音宣告。
    ///
    /// - Parameter text: 宣告文本。
    public func postAnnouncement(_ text: String) {
        // watchOS 下以界面焦点文本朗读为主，故此处作静默宽限降级
    }
}
#endif

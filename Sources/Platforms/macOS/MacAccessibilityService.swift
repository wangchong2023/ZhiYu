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

#if os(macOS)
import AVFoundation

/// macOS 原生平台特化的 VoiceOver 语音宣告服务实现类。
public final class MacAccessibilityService: AccessibilityServiceProtocol, Sendable {
    
    /// 初始化 macOS 辅助功能服务。
    public init() {}
    
    /// 通过系统语音合成器朗读文本，作为 macOS 下的无障碍语音宣告。
    ///
    /// - Note: macOS AppKit 无 `UIAccessibility.post(.announcement)` 等价接口，
    ///   此处用 AVSpeechSynthesizer 朗读文本提供听感反馈。
    /// - Parameter text: 宣告文本。
    public func postAnnouncement(_ text: String) {
        // 本地创建合成器（不存储），避免非 Sendable 状态进入可发送类型
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        synthesizer.speak(utterance)
    }
}
#endif

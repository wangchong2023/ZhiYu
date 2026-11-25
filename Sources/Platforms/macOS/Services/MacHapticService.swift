//
//  MacHapticService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：实现 MacHaptic 模块的核心业务逻辑服务。
//
#if os(macOS)
import AppKit

/// macOS 触感反馈实现：使用 NSHapticFeedbackManager
final class MacHapticService: HapticFeedbackProtocol {

    /// trigger
    /// - Parameter pattern: pattern
    func trigger(_ pattern: HapticPattern) {
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch pattern {
        case .success, .unlock:
            performer.perform(.alignment, performanceTime: .now)
        case .error, .warning, .lock:
            performer.perform(.levelChange, performanceTime: .now)
        case .processing, .link, .selection, .pulse:
            performer.perform(.generic, performanceTime: .now)
        }
    }
}
#endif

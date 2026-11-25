//
//  WatchHapticService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：实现 WatchHaptic 模块的核心业务逻辑服务。
//
#if os(watchOS)
import WatchKit

/// watchOS 触感反馈实现：使用 WKInterfaceDevice.current().play()
final class WatchHapticService: HapticFeedbackProtocol {

    /// trigger
    /// - Parameter pattern: pattern
    func trigger(_ pattern: HapticPattern) {
        let device = WKInterfaceDevice.current()
        switch pattern {
        case .success:
            device.play(.success)
        case .error:
            device.play(.failure)
        case .warning:
            device.play(.retry)
        case .lock:
            device.play(.click)
        case .unlock:
            device.play(.start)
        case .processing, .pulse:
            device.play(.directionDown)
        case .link:
            device.play(.directionUp)
        case .selection:
            device.play(.click)
        }
    }
}
#endif

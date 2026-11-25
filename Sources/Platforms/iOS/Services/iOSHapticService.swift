//
//  iOSHapticService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：实现 iOSHaptic 模块的核心业务逻辑服务。
//
#if os(iOS)
import UIKit

/// iOS 触感反馈实现：使用 UINotificationFeedbackGenerator 和 UIImpactFeedbackGenerator
final class iOSHapticService: HapticFeedbackProtocol {

    /// trigger
    /// - Parameter pattern: pattern
    func trigger(_ pattern: HapticPattern) {
        #if !targetEnvironment(simulator) && !targetEnvironment(macCatalyst)
        switch pattern {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .lock:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .unlock:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .processing, .link, .selection, .pulse:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }
}
#endif

//
//  AppEventBus+ClearDataSubscription.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 功能层
//  核心职责：AppEventBus 扩展，提供 clearAllDataRequested 事件的便捷订阅，消除 ChatService/TaskCenter/SynthesisStore 间的重复订阅链。
//

import Foundation
import Combine

extension AppEventBus {
    /// 订阅 clearAllDataRequested 事件，在主线程执行清理动作
    /// - Parameter action: 收到事件时执行的清理闭包
    /// - Returns: AnyCancellable，由调用方存储以保持订阅
    func subscribeClearAllData(action: @escaping () -> Void) -> AnyCancellable {
        subscribe()
            .receive(on: RunLoop.main)
            .sink { event in
                if case .clearAllDataRequested = event {
                    action()
                }
            }
    }
}

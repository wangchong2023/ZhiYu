//
//  iOSBackgroundTaskProvider.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台实现：后台任务、Widget、文件归档、Spotlight 索引。
//
#if os(iOS) && !os(watchOS)
import Foundation
import BackgroundTasks

final class iOSBackgroundTaskProvider: BackgroundTaskProtocol {
    private let taskIdentifier = "com.zhimind.ingest.process"
    
    /// 注册
    /// - Parameter handler: handler
    /// - Returns: 返回值
    func register(handler: @escaping @Sendable @MainActor () -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            Task { @MainActor in
                handler()
                task.setTaskCompleted(success: true)
            }
        }
    }
    
    /// 调度
    func schedule() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        // iOS 27.0 废弃 submit(_:)，改为 submitTaskRequest(_:completionHandler:) 捕获所有错误条件
        BGTaskScheduler.shared.submitTaskRequest(request) { _ in
            // 静默失败，后台调度非核心关键路径
        }
    }
}
#endif

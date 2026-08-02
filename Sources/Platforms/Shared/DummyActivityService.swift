//
//  DummyActivityService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：实现 DummyActivity 模块的核心业务逻辑服务。
//
import Foundation

/// 实时活动服务的空实现 (No-op)
final class DummyActivityService: LiveActivityProtocol, Sendable {

    /// 启动Activity
    /// - Parameter id: id
    /// - Parameter name: name
    /// - Parameter target: target
    func startActivity(id: UUID, name: String, target: String) {
        // 非支持平台不执行任何操作
    }
    
    func startActivity(
        id: UUID,
        name: String,
        target: String,
        kind: ActivityKind,
        sourceCount: Int,
        currentFileName: String,
        estimatedSecondsRemaining: Int
    ) {
        // 非支持平台不执行任何操作
    }

    /// 更新Progress
    /// - Parameter id: id
    /// - Parameter progress: progress
    /// - Parameter message: message
    func updateProgress(id: UUID, progress: Double, message: String) async {
        // 非支持平台不执行任何操作
    }

    func updateProgress(
        id: UUID,
        progress: Double,
        message: String,
        sourceCount: Int,
        currentFileName: String,
        estimatedSecondsRemaining: Int
    ) async {
        // 非支持平台不执行任何操作
    }

    /// 结束Activity
    /// - Parameter id: id
    func endActivity(id: UUID) async {
        // 非支持平台不执行任何操作
    }
}

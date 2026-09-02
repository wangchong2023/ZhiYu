//
//  LiveActivityProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义 LiveActivity 模块的抽象契约接口。
//
import Foundation

/// 实时活动任务类型
public enum ActivityKind: String, Codable, Hashable, Sendable {
    case synthesis
    case ingestOCR
    case voiceNote
}

/// [Infra] 实时活动服务协议
/// 旨在抹平 iOS 灵动岛 (Live Activity) 与其他平台的差异，实现业务层无宏。
@MainActor
public protocol LiveActivityProtocol: Sendable {
    /// 开启一个新的实时活动
    /// - Parameters:
    ///   - id: 关联的任务 UUID
    ///   - name: 任务名称
    ///   - target: 目标对象名称
    func startActivity(id: UUID, name: String, target: String)
    
    /// 开启包含扩展属性的实时活动（如 AI 合成引用数、文档文件名、预估剩余秒数）
    func startActivity(
        id: UUID,
        name: String,
        target: String,
        kind: ActivityKind,
        sourceCount: Int,
        currentFileName: String,
        estimatedSecondsRemaining: Int
    )

    /// 更新活动进度
    /// - Parameters:
    ///   - id: 任务 UUID
    ///   - progress: 进度值 (0.0 - 1.0)
    ///   - message: 状态描述文本
    func updateProgress(id: UUID, progress: Double, message: String) async
    
    /// 更新包含扩展元数据的活动进度
    func updateProgress(
        id: UUID,
        progress: Double,
        message: String,
        sourceCount: Int,
        currentFileName: String,
        estimatedSecondsRemaining: Int
    ) async

    /// 结束实时活动
    /// - Parameter id: 任务 UUID
    func endActivity(id: UUID) async
}

// MARK: - DependencyKey
import Dependencies
import UFPCore

/// LiveActivityProtocol 的 DependencyKey（可选，返回 nil 时降级为无实时活动）
@MainActor
public enum LiveActivityKey: DependencyKey {
    @MainActor
    public static var liveValue: (any LiveActivityProtocol)? {
        ServiceContainer.shared.resolveOptional((any LiveActivityProtocol).self)
    }

    @MainActor
    public static var testValue: (any LiveActivityProtocol)? {
        ServiceContainer.shared.resolveOptional((any LiveActivityProtocol).self)
    }
    @MainActor
    public static var previewValue: (any LiveActivityProtocol)? { testValue }
}

extension DependencyValues {
    @MainActor
    public var liveActivity: (any LiveActivityProtocol)? {
        get { self[LiveActivityKey.self] }
        set { self[LiveActivityKey.self] = newValue }
    }
}

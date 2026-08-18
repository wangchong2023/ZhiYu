//
//  AIWorkflowCapabilities.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：跨层协议定义，建立 L0-L3 各层间的抽象契约。
//
import Foundation

/// AI 工作流能力协议接口
///
/// 本协议定义了领域层可以直接调用的 AI 工作流关键操作，
/// 通过协议抽象避免领域层（Domain）直接引用具体的业务层 Store（Features），保持架构纯净与单向依赖。
@MainActor
public protocol AIWorkflowCapabilities: AnyObject, Sendable {
    
    /// 移除特定的 AI 重构建议
    ///
    /// 当用户应用或拒绝了某项 AI 优化建议后，调用此方法将其从 activity 缓存中清除。
    /// - Parameter id: 优化建议的唯一标识符 (String)
    func removeRefactorSuggestion(id: String)
}

// MARK: - DependencyKey
import Dependencies
import UFPCore

/// AIWorkflowCapabilities 依赖注入键
@MainActor
public enum AIWorkflowCapabilitiesKey: DependencyKey {
    @MainActor
    public static var liveValue: any AIWorkflowCapabilities {
        ServiceContainer.shared.resolve((any AIWorkflowCapabilities).self)
    }

    @MainActor
    public static var testValue: any AIWorkflowCapabilities {
        ServiceContainer.shared.resolveOptional((any AIWorkflowCapabilities).self) ?? NoOpAIWorkflowCapabilities()
    }
}

/// 无操作 AIWorkflowCapabilities 服务（测试/预览占位，DI 未就绪时降级）
@MainActor
public final class NoOpAIWorkflowCapabilities: AIWorkflowCapabilities, @unchecked Sendable {
    public init() {}
    public func removeRefactorSuggestion(id: String) {}
}

extension DependencyValues {
    @MainActor
    public var aiWorkflowCapabilities: any AIWorkflowCapabilities {
        get { self[AIWorkflowCapabilitiesKey.self] }
        set { self[AIWorkflowCapabilitiesKey.self] = newValue }
    }
}

//
//  RemoteConfigCapabilities.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层 / 协议契约
//  核心职责：定义拉取远程大模型白名单 Manifest 与 Agent 智能技能配置的规范，遵循依赖倒置原则（DIP）。
//

import Foundation

/// 远程配置拉取协议能力契约
public protocol RemoteConfigCapabilities: Sendable {
    
    /// 异步拉取云端大模型兼容白名单列表
    /// - Returns: 大模型清单配置结构列表
    /// - Throws: 网络请求或 JSON 解码异常
    func fetchLLMManifests() async throws -> [LLMManifest]
    
    /// 异步拉取动态 Agent 智能技能（Prompt 模板及超参限制）集合
    /// - Returns: Agent 技能实体列表
    /// - Throws: 网络请求或 JSON 解码异常
    func fetchAgentSkills() async throws -> [AgentSkill]
}

// MARK: - DependencyKey 注册

import Dependencies
import UFPCore

/// RemoteConfigCapabilities 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum RemoteConfigKey: DependencyKey {
    public static var liveValue: any RemoteConfigCapabilities {
        ServiceContainer.shared.resolve((any RemoteConfigCapabilities).self)
    }
}

extension DependencyValues {
    /// 远程配置拉取依赖
    public var remoteConfig: any RemoteConfigCapabilities {
        get { self[RemoteConfigKey.self] }
        set { self[RemoteConfigKey.self] = newValue }
    }
}

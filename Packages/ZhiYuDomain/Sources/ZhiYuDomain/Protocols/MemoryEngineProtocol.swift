//
//  MemoryEngineProtocol.swift
//  ZhiYuDomain
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuDomain]
//  核心职责：领域通用对话记忆与 Episodic 摘要契约协议 (Universal Conversation Memory Protocol)。
//           面向 L3 视图层与 L2 业务层隔离具体底层实现 (自研 Native 引擎 vs 开源 Swarm/Wax 适配器)。
//

import Foundation
import UFPCore

/// 记忆引擎类型
public enum MemoryEngineType: String, Sendable, Codable {
    case native
    case openSourceAdapter
}

/// 简化的 ChatMessage 领域 DTO
public struct ChatMessageDomainDTO: Sendable, Codable, Identifiable {
    public var id: String
    public var role: String
    public var content: String

    public init(id: String = UUID().uuidString, role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

/// 通用对话记忆与 Episodic 摘要契约协议
public protocol MemoryEngineProtocol: Sendable {
    /// 当前记忆引擎类型
    var engineType: MemoryEngineType { get }

    /// 从历史对话中构建短期 Raw 消息队列与长历史 Episodic Summary
    /// - Parameters:
    ///   - history: 原始对话历史消息列表
    ///   - recentCount: 保留的 Raw 消息数量 (默认 5)
    /// - Returns: (历史 Episodic 摘要, 最近 N 轮 Raw 消息列表)
    func processMemory(history: [ChatMessageDomainDTO], recentCount: Int) async -> (summary: String?, recentMessages: [ChatMessageDomainDTO])

    /// 记录并保存特定会话的 Episodic 记忆快照
    /// - Parameters:
    ///   - sessionID: 会话唯一标识
    ///   - summary: 提取的对话背景摘要
    func recordSessionSummary(sessionID: String, summary: String) async throws
}

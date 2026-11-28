//
//  SwarmMemoryAdapter.swift
//  ZhiYuAICore
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuAICore]
//  核心职责：开源 Swarm / Wax 框架记忆引擎适配器存根 (Swarm Memory Adapter)。
//

import Foundation
import UFPCore
import ZhiYuDomain

public final class SwarmMemoryAdapter: MemoryEngineProtocol, Sendable {
    public let engineType: MemoryEngineType = .openSourceAdapter

    public init() {}

    public func processMemory(history: [ChatMessageDomainDTO], recentCount: Int) async -> (summary: String?, recentMessages: [ChatMessageDomainDTO]) {
        // 与 NativeMemoryEngine 语义对齐：空 history 返回 nil summary
        guard !history.isEmpty else {
            return (nil, [])
        }

        // 防御性钳位：recentCount ≤ 0 时回退到 1 保证至少保留最近一条上下文，
        // 避免调用方传入零/负值导致 recentMessages 为空、丢失全部近期对话
        let clampedCount = max(recentCount, MemoryEngineDefaults.minimumRecentCount)
        let recentMessages = Array(history.suffix(clampedCount))
        let olderMessages = history.dropLast(recentMessages.count)

        // 无 older 消息时不生成 summary（与 Native 一致）
        guard !olderMessages.isEmpty else {
            return (nil, recentMessages)
        }

        let summary = "Swarm Agent Memory Summary (\(olderMessages.count) prior items)"
        return (summary, recentMessages)
    }

    public func recordSessionSummary(sessionID: String, summary: String) async throws {
        // Swarm memory sync stub
    }
}

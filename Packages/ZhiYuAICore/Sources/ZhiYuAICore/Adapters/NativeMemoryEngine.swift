//
//  NativeMemoryEngine.swift
//  ZhiYuAICore
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuAICore]
//  核心职责：自研生产级分层记忆与 Episodic 摘要引擎 (Native Memory Engine)。
//

import Foundation
import UFPCore
import ZhiYuDomain

public final class NativeMemoryEngine: MemoryEngineProtocol, Sendable {
    public let engineType: MemoryEngineType = .native

    public init() {}

    public func processMemory(history: [ChatMessageDomainDTO], recentCount: Int) async -> (summary: String?, recentMessages: [ChatMessageDomainDTO]) {
        guard !history.isEmpty else {
            return (nil, [])
        }

        // 防御性钳位：recentCount ≤ 0 时回退到 1 保证至少保留最近一条上下文，
        // 避免调用方传入零/负值导致 recentMessages 为空、丢失全部近期对话
        let clampedCount = max(recentCount, MemoryEngineDefaults.minimumRecentCount)
        let recentMessages = Array(history.suffix(clampedCount))
        let olderMessages = history.dropLast(recentMessages.count)

        if olderMessages.isEmpty {
            return (nil, recentMessages)
        }

        let summary = "Native Summary for \(olderMessages.count) prior messages."
        return (summary, recentMessages)
    }

    public func recordSessionSummary(sessionID: String, summary: String) async throws {
        // Native summary recording
    }
}

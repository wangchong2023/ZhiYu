//
//  NativeMemoryEngine.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：自研分层对话记忆与 Episodic 摘要引擎 (Native Memory Engine)。
//

import Foundation
import UFPCore
import os

/// 自研生产级分层对话记忆引擎
public final class NativeMemoryEngine: MemoryEngineProtocol, @unchecked Sendable {
    public let engineType: MemoryEngineType = .native

    private var sessionSummaries: [String: String] = [:]
    private let lock = OSAllocatedUnfairLock()

    public init() {}

    public func processMemory(
        history: [ChatMessageDTO],
        recentCount: Int = LLMConstants.Memory.recentCountDefault
    ) async -> (summary: String?, recentMessages: [ChatMessageDTO]) {
        guard !history.isEmpty else {
            return (nil, [])
        }

        if history.count <= recentCount {
            return (nil, history)
        }

        // 超出 recentCount 的早期对话组合为背景 Summary 存断言
        let older = history.dropLast(recentCount)
        let recent = Array(history.suffix(recentCount))

        let summaryText = older.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: " | ")
        let summary = "[Conversation Background Summary: \(summaryText.prefix(LLMConstants.LogPreview.memorySummaryLength))]"

        return (summary, recent)
    }

    public func recordSessionSummary(sessionID: String, summary: String) async throws {
        lock.withLock {
            sessionSummaries[sessionID] = summary
        }
    }
}

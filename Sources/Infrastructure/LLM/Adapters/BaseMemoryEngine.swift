//
//  BaseMemoryEngine.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：对话记忆引擎基类，封装通用历史切片提取与线程安全存储。
//

import Foundation
import os

/// 对话记忆引擎通用基类 (DRY)
open class BaseMemoryEngine: MemoryEngineProtocol, @unchecked Sendable {
    open var engineType: MemoryEngineType { .native }
    open var summaryPrefix: String { L10n.AI.Prompt.summaryPrefix }

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

        let older = history.dropLast(recentCount)
        let recent = Array(history.suffix(recentCount))

        let summaryText = older.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: " | ")
        let summary = "[\(summaryPrefix): \(summaryText.prefix(LLMConstants.LogPreview.memorySummaryLength))]"

        return (summary, recent)
    }

    public func recordSessionSummary(sessionID: String, summary: String) async throws {
        lock.withLock {
            sessionSummaries[sessionID] = summary
        }
    }
}

//
//  SwarmMemoryAdapter.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：开源 Swarm / Wax 框架记忆引擎适配器 (Adapter Pattern)。
//           面向 L1.5 MemoryEngineProtocol 契约，支持未来无缝切换至 Swarm 开源 Agent 框架。
//

import Foundation

/// 开源 Swarm / Wax 记忆框架挂载适配器
public final class SwarmMemoryAdapter: MemoryEngineProtocol, @unchecked Sendable {
    public let engineType: MemoryEngineType = .openSourceAdapter

    private var adapterSummaries: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func processMemory(
        history: [ChatMessageDTO],
        recentCount: Int = 5
    ) async -> (summary: String?, recentMessages: [ChatMessageDTO]) {
        guard !history.isEmpty else {
            return (nil, [])
        }

        if history.count <= recentCount {
            return (nil, history)
        }

        let older = history.dropLast(recentCount)
        let recent = Array(history.suffix(recentCount))

        // 模拟/封装开源 Swarm Agent 状态下的记忆切片提取
        let summaryText = older.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: " | ")
        let summary = "[Swarm Agent Memory State: \(summaryText.prefix(300))]"

        return (summary, recent)
    }

    public func recordSessionSummary(sessionID: String, summary: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        adapterSummaries[sessionID] = summary
    }
}

//
//  MockMemoryEngine.swift
//  ZhiYuDomainTestMocks
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuDomainTestMocks]
//  核心职责：MemoryEngineProtocol 的 Mock 存根实现，供业务层与 UI 层单元测试隔离使用。
//

import Foundation
import ZhiYuDomain

public final class MockMemoryEngine: MemoryEngineProtocol, @unchecked Sendable {
    public var engineType: MemoryEngineType

    public init(engineType: MemoryEngineType = .native) {
        self.engineType = engineType
    }

    public func processMemory(history: [ChatMessageDomainDTO], recentCount: Int) async -> (summary: String?, recentMessages: [ChatMessageDomainDTO]) {
        let summary = "Mock Episodic Summary for \(history.count) messages"
        let recent = Array(history.suffix(recentCount))
        return (summary, recent)
    }

    public func recordSessionSummary(sessionID: String, summary: String) async throws {
        // Mock no-op
    }
}

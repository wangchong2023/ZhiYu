//
//  MemoryEngineAdapterTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 MemoryEngineProtocol 面向 L1.5 契约在 NativeMemoryEngine 与 SwarmMemoryAdapter 间的热切换能力。
//

import XCTest
@testable import ZhiYu

@MainActor
final class MemoryEngineAdapterTests: XCTestCase {

    /// 验证 MemoryEngineProtocol 契约隔离性：原生引擎与开源适配器均遵循相同接口契约且可零破坏替换
    func testMemoryEngineAdapterHotSwapping() async throws {
        let engines: [any MemoryEngineProtocol] = [
            NativeMemoryEngine(),
            SwarmMemoryAdapter()
        ]

        let history = (1...10).map { i in
            ChatMessageDTO(role: i % 2 == 1 ? .user : .assistant, content: "Message \(i)")
        }

        for engine in engines {
            let (summary, recent) = await engine.processMemory(history: history, recentCount: 5)
            
            XCTAssertEqual(recent.count, 5, "不同引擎下最近保留数必须严格等于 5 轮")
            XCTAssertNotNil(summary, "超出 5 轮的历史必须被生成为 Episodic Summary")
            XCTAssertEqual(recent.last?.content, "Message 10", "最新一条消息内容必须保留")

            do {
                try await engine.recordSessionSummary(sessionID: "test_session", summary: summary ?? "")
            } catch {
                XCTFail("recordSessionSummary 抛出异常: \(error)")
            }
        }
    }
}

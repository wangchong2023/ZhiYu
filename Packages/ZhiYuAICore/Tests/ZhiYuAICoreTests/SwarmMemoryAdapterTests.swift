//
//  SwarmMemoryAdapterTests.swift
//  ZhiYuAICoreTests
//
//  系统层级：[ZhiYuAICoreTests]
//  核心职责：验证 SwarmMemoryAdapter 的记忆处理语义与 NativeMemoryEngine 的契约一致性。
//

import XCTest
@testable import ZhiYuAICore
import ZhiYuDomain

final class SwarmMemoryAdapterTests: XCTestCase {

    /// engineType 必须是 .openSourceAdapter
    func testEngineTypeIsOpenSourceAdapter() {
        let engine = SwarmMemoryAdapter()
        XCTAssertEqual(engine.engineType, .openSourceAdapter)
    }

    /// 空 history 时 summary 必须为 nil（与 Native 语义对齐）
    func testEmptyHistoryReturnsNilSummary() async {
        let engine = SwarmMemoryAdapter()
        let (summary, recent) = await engine.processMemory(history: [], recentCount: 5)
        XCTAssertTrue(recent.isEmpty)
        XCTAssertNil(summary, "Swarm 空 history 必须返回 nil summary（与 Native 对齐）")
    }

    /// recentCount ≥ history.count 时无 older，summary 必须为 nil
    func testNoOlderMessagesReturnsNilSummary() async {
        let engine = SwarmMemoryAdapter()
        let history = [ChatMessageDomainDTO(role: "user", content: "a")]
        let (summary, recent) = await engine.processMemory(history: history, recentCount: 5)
        XCTAssertEqual(recent.count, 1)
        XCTAssertNil(summary, "无 older 消息时不生成 summary（与 Native 对齐）")
    }

    /// recentMessages 必须是 history 的后缀
    func testRecentMessagesAreSuffix() async {
        let engine = SwarmMemoryAdapter()
        let history = (0..<8).map { i in
            ChatMessageDomainDTO(id: "\(i)", role: "user", content: "m\(i)")
        }
        let (_, recent) = await engine.processMemory(history: history, recentCount: 3)
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(recent.map(\.id), ["5", "6", "7"])
    }

    /// summary 必须包含 older 消息数量（非 history 总数）
    func testSummaryContainsOlderCount() async {
        let engine = SwarmMemoryAdapter()
        let history = (0..<15).map { i in
            ChatMessageDomainDTO(role: "user", content: "\(i)")
        }
        let (summary, _) = await engine.processMemory(history: history, recentCount: 5)
        XCTAssertNotNil(summary)
        // older = 15 - 5 = 10
        XCTAssertTrue(summary?.contains("10") == true, "Swarm summary 必须包含 older 数量（10），非 history 总数（15）")
    }

    /// recentCount=0 时 recent 必须为空
    func testZeroRecentCountEmptyRecent() async {
        let engine = SwarmMemoryAdapter()
        let history = [ChatMessageDomainDTO(role: "user", content: "a")]
        let (_, recent) = await engine.processMemory(history: history, recentCount: 0)
        XCTAssertTrue(recent.isEmpty)
    }

    /// recordSessionSummary 不应抛出异常
    func testRecordSessionSummaryNoThrow() async throws {
        let engine = SwarmMemoryAdapter()
        try await engine.recordSessionSummary(sessionID: "s1", summary: "test")
        XCTAssertTrue(true)
    }

    /// Swarm 与 Native 在相同输入下必须产生相同 summary nilness 语义
    /// （协议多态契约：调用方应能透明替换实现）
    func testSwarmAndNativeSemanticParity() async {
        let engines: [any MemoryEngineProtocol] = [NativeMemoryEngine(), SwarmMemoryAdapter()]

        // 场景 1: 空 history → 两者都返回 nil summary
        for engine in engines {
            let (summary, recent) = await engine.processMemory(history: [], recentCount: 1)
            XCTAssertNil(summary, "\(engine.engineType) 空 history 必须返回 nil summary")
            XCTAssertTrue(recent.isEmpty)
        }

        // 场景 2: recentCount ≥ history.count → 两者都返回 nil summary
        let shortHistory = [ChatMessageDomainDTO(role: "user", content: "a")]
        for engine in engines {
            let (summary, recent) = await engine.processMemory(history: shortHistory, recentCount: 5)
            XCTAssertNil(summary, "\(engine.engineType) 无 older 消息时必须返回 nil summary")
            XCTAssertEqual(recent.count, 1)
        }

        // 场景 3: 有 older 消息 → 两者都返回非 nil summary
        let longHistory = (0..<10).map { _ in ChatMessageDomainDTO(role: "user", content: "x") }
        for engine in engines {
            let (summary, recent) = await engine.processMemory(history: longHistory, recentCount: 3)
            XCTAssertNotNil(summary, "\(engine.engineType) 有 older 消息时必须返回 summary")
            XCTAssertEqual(recent.count, 3)
        }
    }
}

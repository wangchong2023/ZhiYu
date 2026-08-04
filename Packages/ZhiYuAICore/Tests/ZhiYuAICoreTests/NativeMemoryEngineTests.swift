//
//  NativeMemoryEngineTests.swift
//  ZhiYuAICoreTests
//
//  系统层级：[ZhiYuAICoreTests]
//  核心职责：验证 NativeMemoryEngine 的记忆处理语义。
//           空 history 返回 nil summary，recentCount 超过 history 返回全部。
//

import XCTest
@testable import ZhiYuAICore
import ZhiYuDomain

final class NativeMemoryEngineTests: XCTestCase {

    /// engineType 必须是 .native
    func testEngineTypeIsNative() {
        let engine = NativeMemoryEngine()
        XCTAssertEqual(engine.engineType, .native)
    }

    /// 空 history 必须返回 nil summary 和空 recent
    func testEmptyHistoryReturnsNilSummary() async {
        let engine = NativeMemoryEngine()
        let (summary, recent) = await engine.processMemory(history: [], recentCount: 5)
        XCTAssertNil(summary, "空 history 必须返回 nil summary")
        XCTAssertTrue(recent.isEmpty)
    }

    /// history 长度 <= recentCount 时 summary 必须为 nil（无旧消息）
    func testShortHistoryReturnsNilSummary() async {
        let engine = NativeMemoryEngine()
        let history = [ChatMessageDomainDTO(role: "user", content: "a")]
        let (summary, recent) = await engine.processMemory(history: history, recentCount: 5)
        XCTAssertNil(summary, "history <= recentCount 时无旧消息，summary 必须为 nil")
        XCTAssertEqual(recent.count, 1)
    }

    /// history 长度 > recentCount 时 summary 必须非 nil
    func testLongHistoryReturnsNonNilSummary() async {
        let engine = NativeMemoryEngine()
        let history = (0..<10).map { i in
            ChatMessageDomainDTO(role: "user", content: "\(i)")
        }
        let (summary, recent) = await engine.processMemory(history: history, recentCount: 3)
        XCTAssertNotNil(summary, "history > recentCount 时必须生成 summary")
        XCTAssertEqual(recent.count, 3)
    }

    /// summary 必须包含旧消息数量
    func testSummaryContainsOldMessageCount() async {
        let engine = NativeMemoryEngine()
        let history = (0..<10).map { i in
            ChatMessageDomainDTO(role: "user", content: "\(i)")
        }
        let (summary, _) = await engine.processMemory(history: history, recentCount: 3)
        XCTAssertTrue(summary?.contains("7") == true, "summary 必须包含旧消息数（10-3=7）")
    }

    /// recentMessages 必须是 history 的后缀
    func testRecentMessagesAreSuffix() async {
        let engine = NativeMemoryEngine()
        let history = (0..<10).map { i in
            ChatMessageDomainDTO(id: "\(i)", role: "user", content: "m\(i)")
        }
        let (_, recent) = await engine.processMemory(history: history, recentCount: 4)
        XCTAssertEqual(recent.map(\.id), ["6", "7", "8", "9"])
    }

    /// recentCount=0 时 recent 必须为空，summary 仍生成
    func testZeroRecentCountEmptyRecent() async {
        let engine = NativeMemoryEngine()
        let history = (0..<5).map { i in
            ChatMessageDomainDTO(role: "user", content: "\(i)")
        }
        let (summary, recent) = await engine.processMemory(history: history, recentCount: 0)
        XCTAssertTrue(recent.isEmpty)
        XCTAssertNotNil(summary, "recentCount=0 但有 history 时仍应生成 summary")
    }

    /// recordSessionSummary 不应抛出异常
    func testRecordSessionSummaryNoThrow() async throws {
        let engine = NativeMemoryEngine()
        try await engine.recordSessionSummary(sessionID: "s1", summary: "test")
        XCTAssertTrue(true)
    }
}

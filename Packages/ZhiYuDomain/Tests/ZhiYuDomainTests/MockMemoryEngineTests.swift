//
//  MockMemoryEngineTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：验证 MockMemoryEngine 存根的具体行为，确保测试隔离可靠。
//

import XCTest
@testable import ZhiYuDomain
import ZhiYuDomainTestMocks

final class MockMemoryEngineTests: XCTestCase {

    /// Mock 必须返回包含消息数的 summary
    func testMockSummaryContainsMessageCount() async {
        let engine = MockMemoryEngine()
        let history = (0..<7).map { i in
            ChatMessageDomainDTO(role: "user", content: "\(i)")
        }
        let (summary, _) = await engine.processMemory(history: history, recentCount: 3)
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary?.contains("7") == true, "Mock summary 必须包含消息数")
    }

    /// Mock 必须保留指定数量的最近消息
    func testMockRetainsExactRecentCount() async {
        let engine = MockMemoryEngine()
        let history = (0..<10).map { i in
            ChatMessageDomainDTO(id: "\(i)", role: "user", content: "m\(i)")
        }
        let (_, recent) = await engine.processMemory(history: history, recentCount: 4)
        XCTAssertEqual(recent.count, 4)
        XCTAssertEqual(recent.first?.id, "6")
        XCTAssertEqual(recent.last?.id, "9")
    }

    /// Mock engineType 必须可切换
    func testMockEngineTypeSwitchable() {
        let native = MockMemoryEngine(engineType: .native)
        let adapter = MockMemoryEngine(engineType: .openSourceAdapter)
        XCTAssertNotEqual(native.engineType, adapter.engineType)
    }

    /// Mock 默认 engineType 必须是 native
    func testMockDefaultEngineTypeIsNative() {
        let engine = MockMemoryEngine()
        XCTAssertEqual(engine.engineType, .native)
    }

    /// Mock recordSessionSummary 必须是 no-op（不抛错）
    func testMockRecordSessionSummaryIsNoOp() async throws {
        let engine = MockMemoryEngine()
        try await engine.recordSessionSummary(sessionID: "any", summary: "anything")
        // 多次调用也不应崩溃
        try await engine.recordSessionSummary(sessionID: "any2", summary: "")
        XCTAssertTrue(true)
    }
}

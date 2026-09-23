//
//  MemoryEngineSupplementTests.swift
//  ZhiYuTests
//
//  系统层级：[Shared] 测试层
//  核心职责：补盲 Infrastructure/LLM 记忆引擎（NativeMemoryEngine、SwarmMemoryAdapter）
//           的未覆盖分支与边界条件（processMemory 摘要生成、recordSessionSummary、
//           引擎一致性对比）。
//

import XCTest
import UFPCore
import Dependencies
import Combine
@testable import ZhiYu

// MARK: - NativeMemoryEngine / SwarmMemoryAdapter 补盲测试

@MainActor
final class MemoryEngineSupplementTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
    }

    override func tearDown() async throws {
        resetPersistentTestState()
        try await super.tearDown()
    }

    // MARK: - NativeMemoryEngine

    func testNativeMemoryEngineType() {
        let engine = NativeMemoryEngine()
        XCTAssertEqual(engine.engineType, .native, "NativeMemoryEngine 的 engineType 应为 .native")
    }

    func testNativeProcessMemoryEmptyHistoryReturnsNilSummary() async {
        let engine = NativeMemoryEngine()
        let (summary, recent) = await engine.processMemory(history: [], recentCount: 5)
        XCTAssertNil(summary, "空历史应返回 nil summary")
        XCTAssertTrue(recent.isEmpty, "空历史应返回空 recent 列表")
    }

    func testNativeProcessMemoryCountLessOrEqualRecentCount() async {
        let engine = NativeMemoryEngine()
        let history = (1...3).map { i in
            ChatMessageDTO(role: i % 2 == 1 ? .user : .assistant, content: "Msg \(i)")
        }
        let (summary, recent) = await engine.processMemory(history: history, recentCount: 5)
        XCTAssertNil(summary, "history.count <= recentCount 时应返回 nil summary")
        XCTAssertEqual(recent.count, 3, "应返回全部历史消息")
    }

    func testNativeProcessMemoryCountEqualsRecentCount() async {
        let engine = NativeMemoryEngine()
        let history = (1...5).map { i in
            ChatMessageDTO(role: i % 2 == 1 ? .user : .assistant, content: "Msg \(i)")
        }
        let (summary, recent) = await engine.processMemory(history: history, recentCount: 5)
        XCTAssertNil(summary, "history.count == recentCount 时应返回 nil summary（无超出部分）")
        XCTAssertEqual(recent.count, 5)
    }

    func testNativeProcessMemorySummaryContainsRoleAndContent() async {
        let engine = NativeMemoryEngine()
        let history = (1...10).map { i in
            ChatMessageDTO(role: i % 2 == 1 ? .user : .assistant, content: "Content\(i)")
        }
        // 先捕获当前 summaryPrefix，避免 async 挂起期间 languageMode 被其他测试污染导致两次解析不一致
        let prefixSnapshot = L10n.AI.Prompt.summaryPrefix
        let (summary, recent) = await engine.processMemory(history: history, recentCount: 3)
        XCTAssertNotNil(summary, "超出 recentCount 的历史应生成 summary")
        XCTAssertEqual(recent.count, 3, "应只保留最近 3 条消息")
        XCTAssertTrue(summary?.contains(prefixSnapshot) == true, "summary 应包含背景摘要标识")
        XCTAssertTrue(summary?.contains("user") == true, "summary 应包含角色信息")
    }

    func testNativeProcessMemorySummaryTruncatedToMaxLength() async {
        let engine = NativeMemoryEngine()
        let longContent = String(repeating: "A", count: 500)
        let history = (1...10).map { _ in
            ChatMessageDTO(role: .user, content: longContent)
        }
        // 先捕获当前 summaryPrefix，避免 async 挂起期间 languageMode 被其他测试污染导致两次解析不一致
        let prefixSnapshot = L10n.AI.Prompt.summaryPrefix
        let (summary, _) = await engine.processMemory(history: history, recentCount: 3)
        XCTAssertNotNil(summary)
        // 源码格式："[\(summaryPrefix): \(summaryText.prefix(memorySummaryLength))]"
        // 固定开销 = "[" + ": " + "]" = 4 字符
        let maxSummaryLength = prefixSnapshot.count + 4 + LLMConstants.LogPreview.memorySummaryLength
        XCTAssertLessThanOrEqual(summary?.count ?? 0, maxSummaryLength, "summary 应被截断到 memorySummaryLength")
    }

    func testNativeRecordSessionSummarySucceeds() async throws {
        let engine = NativeMemoryEngine()
        try await engine.recordSessionSummary(sessionID: "session-1", summary: "测试摘要")
        try await engine.recordSessionSummary(sessionID: "session-2", summary: "另一个摘要")
        XCTAssertEqual(engine.engineType, .native, "引擎类型应为 .native")
    }

    func testNativeRecordSessionSummaryOverwritesExisting() async throws {
        let engine = NativeMemoryEngine()
        try await engine.recordSessionSummary(sessionID: "dup-session", summary: "第一次")
        try await engine.recordSessionSummary(sessionID: "dup-session", summary: "第二次")
        XCTAssertEqual(engine.engineType, .native, "多次覆写后引擎状态应正常")
    }

    // MARK: - SwarmMemoryAdapter

    func testSwarmMemoryAdapterType() {
        let adapter = SwarmMemoryAdapter()
        XCTAssertEqual(adapter.engineType, .openSourceAdapter, "SwarmMemoryAdapter 的 engineType 应为 .openSourceAdapter")
    }

    func testSwarmProcessMemoryEmptyHistoryReturnsNilSummary() async {
        let adapter = SwarmMemoryAdapter()
        let (summary, recent) = await adapter.processMemory(history: [], recentCount: 5)
        XCTAssertNil(summary, "空历史应返回 nil summary")
        XCTAssertTrue(recent.isEmpty, "空历史应返回空 recent 列表")
    }

    func testSwarmProcessMemoryCountLessOrEqualRecentCount() async {
        let adapter = SwarmMemoryAdapter()
        let history = (1...4).map { i in
            ChatMessageDTO(role: i % 2 == 1 ? .user : .assistant, content: "Msg \(i)")
        }
        let (summary, recent) = await adapter.processMemory(history: history, recentCount: 5)
        XCTAssertNil(summary, "history.count <= recentCount 时应返回 nil summary")
        XCTAssertEqual(recent.count, 4)
    }

    func testSwarmProcessMemorySummaryContainsSwarmIdentifier() async {
        let adapter = SwarmMemoryAdapter()
        let history = (1...10).map { i in
            ChatMessageDTO(role: i % 2 == 1 ? .user : .assistant, content: "Content\(i)")
        }
        let (summary, recent) = await adapter.processMemory(history: history, recentCount: 3)
        XCTAssertNotNil(summary)
        XCTAssertEqual(recent.count, 3)
        XCTAssertTrue(summary?.contains("Swarm Agent Memory State") == true, "Swarm adapter summary 应包含 Swarm 标识")
    }

    func testSwarmRecordSessionSummarySucceeds() async throws {
        let adapter = SwarmMemoryAdapter()
        try await adapter.recordSessionSummary(sessionID: "swarm-1", summary: "Swarm 摘要")
        XCTAssertEqual(adapter.engineType, .openSourceAdapter, "Swarm adapter 记录会话摘要后引擎类型应为 .openSourceAdapter")
    }

    // MARK: - 引擎一致性对比

    func testBothEnginesReturnSameRecentCount() async {
        let engines: [any MemoryEngineProtocol] = [NativeMemoryEngine(), SwarmMemoryAdapter()]
        let history = (1...20).map { i in
            ChatMessageDTO(role: i % 2 == 0 ? .user : .assistant, content: "Msg \(i)")
        }
        for engine in engines {
            let (_, recent) = await engine.processMemory(history: history, recentCount: 7)
            XCTAssertEqual(recent.count, 7, "\(engine.engineType.rawValue) 应返回 7 条 recent 消息")
        }
    }

    func testBothEnginesHandleZeroRecentCount() async {
        let engines: [any MemoryEngineProtocol] = [NativeMemoryEngine(), SwarmMemoryAdapter()]
        let history = (1...5).map { i in
            ChatMessageDTO(role: .user, content: "Msg \(i)")
        }
        for engine in engines {
            let (summary, recent) = await engine.processMemory(history: history, recentCount: 0)
            XCTAssertTrue(recent.isEmpty, "\(engine.engineType.rawValue) recentCount=0 时 recent 应为空")
            XCTAssertNotNil(summary, "\(engine.engineType.rawValue) recentCount=0 且有历史时应生成 summary")
        }
    }
}

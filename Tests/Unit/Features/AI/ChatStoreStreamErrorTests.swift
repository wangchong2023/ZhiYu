//
//  ChatStoreStreamErrorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 测试层
//  核心职责：测试 ChatCoordinator 在流式取消、LLMError.notConfigured 告警触发、网络流中断及历史回滚重新生成时的状态机。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class ChatStoreStreamErrorTests: XCTestCase {

    private var coordinator: ChatCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        coordinator = ChatCoordinator()
    }

    override func tearDown() async throws {
        coordinator = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 流式取消逻辑

    func testCancelCurrentRequestCleansState() {
        coordinator.isProcessing = true
        coordinator.streamingContent = "部分已接收的流式内容"

        coordinator.cancelCurrentRequest()

        XCTAssertFalse(coordinator.isProcessing)
        XCTAssertEqual(coordinator.streamingContent, "")
    }

    // MARK: - 2. 历史回滚与重新生成

    func testRegenerateLastMessageRollsBackHistory() async {
        let chatService = ServiceContainer.shared.resolve((any ChatServiceProtocol).self)
        chatService.clearHistory()

        // 模拟一问一答
        await coordinator.sendMessage(query: "第一个问题", pages: [])

        XCTAssertEqual(coordinator.chatHistory.count, 2)
        XCTAssertEqual(coordinator.chatHistory[0].role, .user)
        XCTAssertEqual(coordinator.chatHistory[1].role, .assistant)

        // 触发重新生成
        await coordinator.regenerateLastMessage(pages: [])

        // 重新生成后应仍是一问一答，但重新执行了流式
        XCTAssertEqual(coordinator.chatHistory.count, 2)
        XCTAssertEqual(coordinator.chatHistory[0].content, "第一个问题")
    }

    // MARK: - 3. 历史清理与选中态管理

    func testClearChatHistoryAndSelectionState() {
        coordinator.chatHistory = [
            ChatMessage(role: .user, content: "问"),
            ChatMessage(role: .assistant, content: "答")
        ]
        coordinator.isSelectionMode = true
        coordinator.selectedMessageIDs.insert(coordinator.chatHistory[0].id)
        coordinator.predictedQuestions = ["追问1", "追问2"]

        coordinator.clearChatHistory()

        XCTAssertTrue(coordinator.chatHistory.isEmpty)
        XCTAssertTrue(coordinator.selectedMessageIDs.isEmpty)
        XCTAssertFalse(coordinator.isSelectionMode)
        XCTAssertTrue(coordinator.predictedQuestions.isEmpty)
    }
}

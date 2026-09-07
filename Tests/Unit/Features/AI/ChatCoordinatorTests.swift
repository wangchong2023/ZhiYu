//
//  ChatCoordinatorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 ChatCoordinator 的状态管理与对话历史操作。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class ChatCoordinatorTests: XCTestCase {

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

    // MARK: - 初始状态

    /// 验证初始 inputText 为空
    func testInitialInputTextEmpty() {
        XCTAssertEqual(coordinator.inputText, "")
    }

    /// 验证初始 chatHistory 为空
    func testInitialChatHistoryEmpty() {
        XCTAssertTrue(coordinator.chatHistory.isEmpty)
    }

    /// 验证初始 isProcessing 为 false
    func testInitialIsProcessingFalse() {
        XCTAssertFalse(coordinator.isProcessing)
    }

    /// 验证初始 isSelectionMode 为 false
    func testInitialIsSelectionModeFalse() {
        XCTAssertFalse(coordinator.isSelectionMode)
    }

    /// 验证初始 selectedMessageIDs 为空
    func testInitialSelectedMessageIDsEmpty() {
        XCTAssertTrue(coordinator.selectedMessageIDs.isEmpty)
    }

    /// 验证初始 predictedQuestions 为空
    func testInitialPredictedQuestionsEmpty() {
        XCTAssertTrue(coordinator.predictedQuestions.isEmpty)
    }

    /// 验证初始 errorMessage 为 nil
    func testInitialErrorMessageNil() {
        XCTAssertNil(coordinator.errorMessage)
    }

    // MARK: - clearChatHistory

    /// 验证 clearChatHistory 清空 chatHistory
    func testClearChatHistoryEmptiesChatHistory() {
        coordinator.chatHistory.append(ChatMessage(role: .user, content: "test"))
        coordinator.chatHistory.append(ChatMessage(role: .assistant, content: "reply"))

        coordinator.clearChatHistory()

        XCTAssertTrue(coordinator.chatHistory.isEmpty)
    }

    /// 验证 clearChatHistory 清空 predictedQuestions
    func testClearChatHistoryEmptiesPredictedQuestions() {
        coordinator.predictedQuestions = ["q1", "q2"]

        coordinator.clearChatHistory()

        XCTAssertTrue(coordinator.predictedQuestions.isEmpty)
    }

    // MARK: - toggleSelectionMode

    /// 验证 toggleSelectionMode 切换 isSelectionMode
    func testToggleSelectionModeTogglesFlag() {
        XCTAssertFalse(coordinator.isSelectionMode)

        coordinator.toggleSelectionMode()
        XCTAssertTrue(coordinator.isSelectionMode)

        coordinator.toggleSelectionMode()
        XCTAssertFalse(coordinator.isSelectionMode)
    }

    /// 验证关闭选择模式时清空 selectedMessageIDs
    func testToggleSelectionModeClearsSelectionWhenOff() {
        coordinator.selectedMessageIDs.insert(UUID())
        coordinator.isSelectionMode = true

        coordinator.toggleSelectionMode()

        XCTAssertFalse(coordinator.isSelectionMode)
        XCTAssertTrue(coordinator.selectedMessageIDs.isEmpty)
    }

    // MARK: - toggleMessageSelection

    /// 验证 toggleMessageSelection 添加未选中的 ID
    func testToggleMessageSelectionAddsID() {
        let id = UUID()

        coordinator.toggleMessageSelection(id)

        XCTAssertTrue(coordinator.selectedMessageIDs.contains(id))
    }

    /// 验证 toggleMessageSelection 移除已选中的 ID
    func testToggleMessageSelectionRemovesID() {
        let id = UUID()
        coordinator.selectedMessageIDs.insert(id)

        coordinator.toggleMessageSelection(id)

        XCTAssertFalse(coordinator.selectedMessageIDs.contains(id))
    }

    // MARK: - cancelCurrentRequest

    /// 验证 cancelCurrentRequest 设置 isProcessing 为 false
    func testCancelCurrentRequestSetsIsProcessingFalse() {
        coordinator.isProcessing = true

        coordinator.cancelCurrentRequest()

        XCTAssertFalse(coordinator.isProcessing)
    }

    /// 验证 cancelCurrentRequest 清空 streamingContent
    func testCancelCurrentRequestClearsStreamingContent() {
        coordinator.streamingContent = "partial content"
        coordinator.isProcessing = true

        coordinator.cancelCurrentRequest()

        XCTAssertEqual(coordinator.streamingContent, "")
    }

    // MARK: - sendMessage 空输入保护

    /// 验证 sendMessage 空字符串不处理
    func testSendMessageEmptyStringNoOp() async {
        await coordinator.sendMessage(query: "   ", pages: [])
        XCTAssertTrue(coordinator.chatHistory.isEmpty)
        XCTAssertFalse(coordinator.isProcessing)
    }

    /// 验证 sendMessage nil 且 inputText 空不处理
    func testSendMessageNilQueryEmptyInputNoOp() async {
        coordinator.inputText = ""
        await coordinator.sendMessage(query: nil, pages: [])
        XCTAssertTrue(coordinator.chatHistory.isEmpty)
    }

    /// 验证 clearChatHistory 重置多选模式和已选消息列表，防止幽灵选区状态残留
    func testClearChatHistoryResetsSelectionState() {
        let dummyID = UUID()
        coordinator.isSelectionMode = true
        coordinator.selectedMessageIDs = [dummyID]
        coordinator.chatHistory.append(ChatMessage(id: dummyID, role: .user, content: "test"))

        coordinator.clearChatHistory()

        XCTAssertFalse(coordinator.isSelectionMode, "清空历史后必须重置多选模式")
        XCTAssertTrue(coordinator.selectedMessageIDs.isEmpty, "清空历史后已选消息集合必须清空")
    }
}

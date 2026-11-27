//
//  ChatCoordinatorStreamFaultInjectionTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYuUnitTestHost

@MainActor
final class ChatCoordinatorStreamFaultInjectionTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. Stream Send, Cancel, and Truncation Protection

    func testChatCoordinatorSendAndCancelFlow() async throws {
        let coordinator = ChatCoordinator()
        let pages = [KnowledgePage(title: "Architecture", pageType: .concept, content: "RAG & LLM details")]

        // 1. 发送空文本防御拦截（先清空历史，确保从纯净状态开始）
        coordinator.clearChatHistory()
        await coordinator.sendMessage(query: "   ", pages: pages)
        XCTAssertTrue(coordinator.chatHistory.isEmpty)

        // 2. 超长文本截断保护发送
        let superLongText = String(repeating: "A", count: PromptConstants.TokenLimits.maxUserInputLength + 500)
        let sendTask = Task {
            await coordinator.sendMessage(query: superLongText, pages: pages)
        }

        // 3. 中途主动中断请求
        try? await Task.sleep(nanoseconds: 10_000_000)
        coordinator.cancelCurrentRequest()
        _ = await sendTask.value

        XCTAssertFalse(coordinator.isProcessing)
        XCTAssertEqual(coordinator.streamingContent, "")
    }

    // MARK: - 2. Selection Mode & Export & Clear History

    func testSelectionModeAndExportAndRegenerate() async throws {
        let coordinator = ChatCoordinator()
        let pages = [KnowledgePage(title: "Knowledge", pageType: .concept, content: "Body")]

        // 模拟已有历史
        let msg1 = ChatMessage(role: .user, content: "What is Swift 6?")
        let msg2 = ChatMessage(role: .assistant, content: "Swift 6 features complete concurrency.")
        coordinator.chatHistory = [msg1, msg2]

        // 1. 切换选择模式
        coordinator.toggleSelectionMode()
        XCTAssertTrue(coordinator.isSelectionMode)

        // 2. 选中消息
        coordinator.toggleMessageSelection(msg1.id)
        XCTAssertTrue(coordinator.selectedMessageIDs.contains(msg1.id))

        // 反选消息
        coordinator.toggleMessageSelection(msg1.id)
        XCTAssertFalse(coordinator.selectedMessageIDs.contains(msg1.id))

        // 3. 导出对话 PDF
        await coordinator.exportChat()

        // 4. 重新生成最后一次回复
        await coordinator.regenerateLastMessage(pages: pages)

        // 5. 清除历史
        coordinator.clearChatHistory()
        XCTAssertTrue(coordinator.chatHistory.isEmpty)
        XCTAssertTrue(coordinator.predictedQuestions.isEmpty)
        XCTAssertFalse(coordinator.isSelectionMode)
    }

    // MARK: - 3. Insightful & Follow-up Questions

    func testInsightfulAndFollowUpQuestions() async throws {
        let coordinator = ChatCoordinator()
        let pages = [KnowledgePage(title: "Insight", pageType: .concept, content: "Sample")]

        // 1. 空页面防御
        await coordinator.loadInsightfulQuestions(pages: [])
        XCTAssertTrue(coordinator.insightfulQuestions.isEmpty)

        // 2. 预测后续追问
        await coordinator.generatePredictedQuestions(pages: pages)
    }

    // MARK: - 4. 缺陷 #226 回归：流式生成中途清史不产生幽灵回复，流式中重新生成不丢失用户提问

    func testClearHistoryDuringStreamingCancelsStreamAndPreventsGhostReply() async {
        let coordinator = ChatCoordinator()
        coordinator.clearChatHistory()
        let pages = [KnowledgePage(title: "Test", pageType: .concept, content: "Content")]

        let sendTask = Task {
            await coordinator.sendMessage(query: "请解释量子纠缠", pages: pages)
        }
        try? await Task.sleep(for: .milliseconds(5))
        coordinator.clearChatHistory()
        await sendTask.value

        XCTAssertTrue(coordinator.chatHistory.isEmpty, "流式生成中途清史后不得出现幽灵 AI 回复")
        XCTAssertFalse(coordinator.isProcessing)
        XCTAssertEqual(coordinator.streamingContent, "")
    }

    func testRegenerateWhileProcessingDoesNotDropLastUserMessage() async {
        let coordinator = ChatCoordinator()
        coordinator.clearChatHistory()
        let pages = [KnowledgePage(title: "Test", pageType: .concept, content: "Content")]

        coordinator.chatHistory = [ChatMessage(role: .user, content: "核心架构问题")]
        coordinator.status = .loading(L10n.Chat.aiRunning)

        await coordinator.regenerateLastMessage(pages: pages)

        XCTAssertTrue(
            coordinator.chatHistory.contains { $0.role == .user && $0.content == "核心架构问题" },
            "流式进行中触发重新生成时必须先取消旧流并保留用户原提问"
        )
    }
}

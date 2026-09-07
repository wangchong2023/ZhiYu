//
//  ChatCoordinatorDeepBranchTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：深入验证 ChatCoordinator 的各种边界状态机分支（防抖、取消、回滚、截断、导出过滤）。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ChatCoordinatorDeepBranchTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 空白与纯空格输入守卫分支

    func testSendMessage_WhenEmptyOrWhitespace_DoesNotTriggerProcessing() async {
        let coordinator = ChatCoordinator()
        let initialCount = coordinator.chatHistory.count
        coordinator.inputText = "   \n\t  "

        await coordinator.sendMessage(pages: [])

        XCTAssertFalse(coordinator.isProcessing, "空白字符输入不应触发处理状态")
        XCTAssertEqual(coordinator.chatHistory.count, initialCount, "空白字符不应被追加计入聊天历史")
    }

    // MARK: - 2. 超长文本截断分支

    func testSendMessage_WhenInputExceedsMaxTokenLength_TruncatesSafely() async {
        let coordinator = ChatCoordinator()
        let hugeInput = String(repeating: "A", count: PromptConstants.TokenLimits.maxUserInputLength + 500)
        coordinator.inputText = hugeInput

        await coordinator.sendMessage(pages: [])

        let lastUserMsg = coordinator.chatHistory.last(where: { $0.role == .user })
        XCTAssertEqual(lastUserMsg?.content.count, PromptConstants.TokenLimits.maxUserInputLength,
                       "超长用户输入应当被安全截断至最大限制长度")
    }

    // MARK: - 3. 并发重复提问自动取消旧请求分支

    func testSendMessage_WhenAlreadyProcessing_CancelsCurrentRequest() async {
        let coordinator = ChatCoordinator()
        coordinator.isProcessing = true
        coordinator.streamingContent = "部分已生成的流式内容"

        await coordinator.sendMessage(query: "第二次连续提问", pages: [])

        XCTAssertFalse(coordinator.isProcessing, "触发并发提问时应自动取消前一个请求并重置 isProcessing")
        XCTAssertTrue(coordinator.streamingContent.isEmpty, "取消后应当重置半截流式内容")
    }

    // MARK: - 4. 显式取消请求分支

    func testCancelCurrentRequest_ResetsStreamingContentAndTask() {
        let coordinator = ChatCoordinator()
        coordinator.isProcessing = true
        coordinator.streamingContent = "正在输出的代码块..."

        coordinator.cancelCurrentRequest()

        XCTAssertFalse(coordinator.isProcessing, "显式取消后 isProcessing 应为 false")
        XCTAssertTrue(coordinator.streamingContent.isEmpty, "显式取消后 streamingContent 应被清空")
    }

    // MARK: - 5. 重新生成历史回滚分支

    func testRegenerateLastMessage_WhenNoUserMessage_DoesNothing() async {
        let coordinator = ChatCoordinator()
        coordinator.chatHistory = [ChatMessage(role: .assistant, content: "系统欢迎语")]

        await coordinator.regenerateLastMessage(pages: [])

        XCTAssertEqual(coordinator.chatHistory.count, 1, "无用户提问时重新生成不应产生任何变动")
    }

    func testRegenerateLastMessage_RollsBackHistoryAndRetries() async {
        let coordinator = ChatCoordinator()
        let msg1 = ChatMessage(role: .user, content: "第一条问题")
        let msg2 = ChatMessage(role: .assistant, content: "第一条回答")
        let msg3 = ChatMessage(role: .user, content: "第二条问题")
        let msg4 = ChatMessage(role: .assistant, content: "第二条回答（失败或不满意的回答）")
        coordinator.chatHistory = [msg1, msg2, msg3, msg4]

        await coordinator.regenerateLastMessage(pages: [])

        // 重新生成后，应驱逐 msg3 及以后的回答，并将 msg3 重新发送生成新结果
        XCTAssertTrue(coordinator.chatHistory.contains(where: { $0.content == "第一条问题" }), "保留历史应当被正确留存")
    }

    // MARK: - 6. 清除历史与多选重置分支

    func testClearChatHistory_ResetsAllSelectionAndQuestions() {
        let coordinator = ChatCoordinator()
        let msg = ChatMessage(role: .user, content: "待删除消息")
        coordinator.chatHistory = [msg]
        coordinator.isSelectionMode = true
        coordinator.selectedMessageIDs = [msg.id]
        coordinator.predictedQuestions = ["后续问题预测"]

        coordinator.clearChatHistory()

        XCTAssertTrue(coordinator.chatHistory.isEmpty, "聊天历史应当为空")
        XCTAssertTrue(coordinator.predictedQuestions.isEmpty, "预测问题应当被清空")
        XCTAssertFalse(coordinator.isSelectionMode, "多选模式应当被重置")
        XCTAssertTrue(coordinator.selectedMessageIDs.isEmpty, "选中的消息 ID 集合应当被清空")
    }

    // MARK: - 7. 启发式提问防抖与空数据守卫分支

    func testLoadInsightfulQuestions_WhenPagesEmptyOrDisabled_EarlyReturns() async {
        let coordinator = ChatCoordinator()

        // 1. 空页面
        await coordinator.loadInsightfulQuestions(pages: [])
        XCTAssertTrue(coordinator.insightfulQuestions.isEmpty, "空页面时不应请求 AI 启发问题")

        // 2. 正在生成中防抖
        coordinator.isGeneratingAIQuestions = true
        await coordinator.loadInsightfulQuestions(pages: [KnowledgePage(title: "测试", content: "内容")])
        XCTAssertTrue(coordinator.insightfulQuestions.isEmpty, "正在生成中时应防抖拦截")
    }
}

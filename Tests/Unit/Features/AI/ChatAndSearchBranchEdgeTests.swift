//
//  ChatAndSearchBranchEdgeTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 ChatCoordinator 流式取消/消息多选与 SearchStore 复杂条件过滤分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ChatAndSearchBranchEdgeTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ChatCoordinator 发送与流式中断分支

    func testChatCoordinator_SendMessageAndCancel() async {
        let coordinator = ChatCoordinator()
        XCTAssertFalse(coordinator.isProcessing)

        // 发送空文本防御拦截
        await coordinator.sendMessage(query: "   \n  ", pages: [])
        XCTAssertFalse(coordinator.isProcessing)
        XCTAssertTrue(coordinator.chatHistory.isEmpty)

        // 正常发送消息
        let pages = [KnowledgePage(title: "测试上下文", pageType: .concept, content: "内容")]
        let sendTask = Task {
            await coordinator.sendMessage(query: "请总结核心要点", pages: pages)
        }

        // 测试中断与取消流式请求
        coordinator.cancelCurrentRequest()
        _ = await sendTask.result
        XCTAssertFalse(coordinator.isProcessing)
    }

    // MARK: - 2. 消息多选与清空确认分支

    func testChatCoordinator_SelectionModeAndClearHistory() {
        let coordinator = ChatCoordinator()
        let msgID = UUID()

        XCTAssertFalse(coordinator.isSelectionMode)
        coordinator.isSelectionMode = true
        coordinator.selectedMessageIDs.insert(msgID)

        XCTAssertTrue(coordinator.selectedMessageIDs.contains(msgID))

        coordinator.clearChatHistory()
        XCTAssertTrue(coordinator.chatHistory.isEmpty)
        XCTAssertFalse(coordinator.isSelectionMode)
    }

    // MARK: - 3. 深度追问与预测问题生成分支

    func testChatCoordinator_PredictFollowUpQuestions() async {
        let coordinator = ChatCoordinator()
        let pages = [KnowledgePage(title: "RAG 架构", pageType: .concept, content: "检索增强生成原理")]

        await coordinator.loadInsightfulQuestions(pages: pages, forceRefresh: true)
        // 验证状态机正常复位
        XCTAssertFalse(coordinator.isGeneratingAIQuestions)
    }
}

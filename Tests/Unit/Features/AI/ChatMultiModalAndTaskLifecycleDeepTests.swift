//
//  ChatMultiModalAndTaskLifecycleDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ChatMultiModalAndTaskLifecycleDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        store.pages = []
        @Dependency(\.taskCenter) var taskCenter
        taskCenter.reset()
        try await super.tearDown()
    }

    // MARK: - 1. TaskCenter Lifecycle & Metrics Tests

    func testTaskCenterLifecycleAndFilter() async throws {
        @Dependency(\.taskCenter) var taskCenter

        // 1. 创建各类后台任务
        let id1 = taskCenter.addTask(type: .ai, name: "Semantic Chunking", target: "12 Documents")
        let id2 = taskCenter.addTask(type: .ingest, name: "PDF Import", target: "MachineLearning.pdf")
        let id3 = taskCenter.addTask(type: .synthesis, name: "Knowledge Synthesis", target: "Weekly Report")

        taskCenter.updateTask(id1, status: .running(progress: 0.45, stage: .chunking))
        taskCenter.updateTask(id2, status: .failed(error: "Timeout"))
        taskCenter.updateTask(id3, status: .completed)

        XCTAssertEqual(taskCenter.tasks.count, 3)

        // 验证指标计算
        let aiMetrics = taskCenter.metrics(for: .ai)
        XCTAssertEqual(aiMetrics.total, 1)

        // 标记已读与清除任务
        taskCenter.markAsRead(id1)
        taskCenter.removeTask(id2)
        XCTAssertEqual(taskCenter.tasks.count, 2)

        // 渲染 TaskCenterView
        let taskCenterView = TaskCenterView()
            .snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: taskCenterView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. ChatView & ChatCoordinator Deep Tests

    func testChatViewAndCoordinatorState() async throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        let page = KnowledgePage(
            title: "Karpathy AI Summary",
            pageType: .concept,
            content: "RAG and LLM Wiki integration patterns."
        )
        store.pages = [page]

        let coordinator = ChatCoordinator()
        await coordinator.loadInsightfulQuestions(pages: store.pages)

        // 验证对话输入与清空历史
        coordinator.inputText = "Explain RAG architecture."
        XCTAssertEqual(coordinator.inputText, "Explain RAG architecture.")

        coordinator.clearChatHistory()
        XCTAssertTrue(coordinator.chatHistory.isEmpty)

        // 验证 ChatView 渲染
        var selectedTab: AppTab = .chat
        let binding = Binding(get: { selectedTab }, set: { selectedTab = $0 })
        let chatView = ChatView(selectedTab: binding)
            .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: chatView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }
}

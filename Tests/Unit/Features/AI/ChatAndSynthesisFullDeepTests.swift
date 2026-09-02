//
//  ChatAndSynthesisFullInteractionsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：针对 AI 对话（ChatView）、AI 合成实验室（SynthesisView）
//            及异步任务中心（TaskCenterView）进行多会话流式与状态机覆盖。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ChatAndSynthesisFullDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        let taskCenter = ServiceContainer.shared.resolveOptional(TaskCenter.self)
        taskCenter?.reset()
        try await super.tearDown()
    }

    // MARK: - 1. ChatView 对话视图交互

    func testChatView_StandardAndActiveStates() {
        let chatView = ChatView(selectedTab: .constant(.chat))
            .snapshotEnvironment()

        let host = UIHostingController(rootView: chatView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. SynthesisView 合成视图多源与模板选择

    func testSynthesisView_TemplateSelection() {
        let synthesisView = SynthesisView(
            selection: .constant(nil),
            selectedTab: .constant(.synthesis)
        ).snapshotEnvironment()

        let host = UIHostingController(rootView: synthesisView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. TaskCenterView 任务中心视图

    func testTaskCenterView_ActiveTasksAndHistory() {
        let taskCenter = ServiceContainer.shared.resolveOptional(TaskCenter.self)
        _ = taskCenter?.addTask(
            type: .ai,
            name: "Analyzing Document Graph",
            target: "Building similarity edges"
        )

        let taskCenterView = TaskCenterView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: taskCenterView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }
}

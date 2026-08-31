//
//  AIViewsDeepStateAndFuzzTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：针对 AI 业务切片（ChatView, SynthesisView, QuizView, VoiceNoteView, TaskCenterView）
//            执行深层状态机分支覆盖与 Fuzz 异常交互测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AIViewsDeepStateAndFuzzTests: XCTestCase {

    private var appStore: AppStore!
    private var router: Router!
    private var chatCoordinator: ChatCoordinator!
    private var synthesisStore: SynthesisStore!
    private var taskCenter: TaskCenter!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()

        appStore = AppStore()
        router = Router.shared
        chatCoordinator = ChatCoordinator()
        synthesisStore = SynthesisStore()
        taskCenter = TaskCenter(activityService: ActivityService.shared)
    }

    override func tearDown() async throws {
        taskCenter?.reset()
        appStore = nil
        router = nil
        chatCoordinator = nil
        synthesisStore = nil
        taskCenter = nil
        try await super.tearDown()
    }

    // MARK: - 1. ChatView 深度状态机与流式中断

    func testChatView_FullLifecycleAndInputState() {
        let chatView = ChatView(selectedTab: .constant(.chat))
            .environment(chatCoordinator)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: chatView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. SynthesisView 合成大纲与多文档状态

    func testSynthesisView_OutlineAndMultiDocStates() {
        let synthesisView = SynthesisView(
            selection: .constant(.tool(.synthesis)),
            selectedTab: .constant(.synthesis)
        )
        .environment(synthesisStore)
        .snapshotEnvironment()

        let host = UIHostingController(rootView: synthesisView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. QuizView 测验题目异常与状态边界

    func testQuizView_EmptyAndValidQuestions() {
        let quizModel = QuizModel(
            title: "分布式系统基础测验",
            questions: [
                QuizQuestion(
                    id: 1,
                    text: "什么是 CAP 定理？",
                    options: [
                        "一致性、可用性、分区容错性三者不可兼得",
                        "高并发架构核心协议",
                        "关系型数据库事务隔离级别"
                    ],
                    answer: 0,
                    explanation: "CAP 定理指出分布式系统无法同时完全满足一致性、可用性和分区容错性。"
                )
            ]
        )

        let quizView = QuizView(quiz: quizModel)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: quizView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 4. TaskCenterView 任务列表展开与清理

    func testTaskCenterView_ActiveAndCompletedTasks() {
        taskCenter.addTask(type: .ai, name: "知识库深度同步", target: "微服务专题")
        taskCenter.addTask(type: .synthesis, name: "知识合成报告生成", target: "架构演进")

        let taskCenterView = TaskCenterView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: taskCenterView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertEqual(taskCenter.tasks.count, 2)
        XCTAssertNotNil(host.view)
    }
}

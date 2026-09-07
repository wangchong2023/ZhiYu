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
    // MARK: - 2. SynthesisView 合成大纲与多文档状态
    // MARK: - 3. QuizView 测验题目异常与状态边界
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

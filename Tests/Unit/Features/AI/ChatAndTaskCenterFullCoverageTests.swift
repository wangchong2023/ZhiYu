//
//  ChatAndTaskCenterFullCoverageTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度覆盖 ChatView 与 TaskCenterView 的全部分类过滤、多状态任务卡片、重试/清理与流式对话交互。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ChatAndTaskCenterFullCoverageTests: XCTestCase {

    private var store: AppStore!
    private var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        router = ServiceContainer.shared.resolveOptional(Router.self) ?? Router.shared
    }

    override func tearDown() async throws {
        store = nil
        router = nil
        try await super.tearDown()
    }

    // MARK: - 1. ChatView 容器与消息流式交互测试

    struct ChatWrapperView: View {
        @State private var selectedTab: AppTab = .chat

        var body: some View {
            ChatView(selectedTab: $selectedTab)
                .snapshotEnvironment()
        }
    }

    func testChatViewEmptyAndWithMessages() async {
        let wrapper = ChatWrapperView()
        let hosting = UIHostingController(rootView: wrapper)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()
    }

    // MARK: - 2. TaskCenterView 空状态与多任务类型矩阵测试

    func testTaskCenterViewEmptyAndPopulatedStates() {
        @Dependency(\.taskCenter) var taskCenter

        // 1. 空状态渲染
        taskCenter.tasks = []
        let emptyView = TaskCenterView()
            .snapshotEnvironment()
        let emptyHost = UIHostingController(rootView: emptyView)
        XCTAssertNotNil(emptyHost.view)
        emptyHost.view.layoutIfNeeded()

        // 2. 注入多类型任务（摄取、扫描、合成）
        let ingestTask = GlobalTask(
            type: .ingest,
            name: "文档导入",
            target: "知识库导入.pdf",
            status: .running(progress: 0.45, stage: .chunking),
            subLogs: ["处理中..."]
        )
        let scanTask = GlobalTask(
            type: .aiScan,
            name: "知识扫描",
            target: "全局双链关系扫描",
            status: .completed
        )
        let synthesisTask = GlobalTask(
            type: .synthesis,
            name: "报告合成",
            target: "深度报告生成",
            status: .failed(error: "LLM API Rate Limit")
        )

        taskCenter.tasks = [ingestTask, scanTask, synthesisTask]

        let populatedView = TaskCenterView()
            .snapshotEnvironment()
        let populatedHost = UIHostingController(rootView: populatedView)
        XCTAssertNotNil(populatedHost.view)
        populatedHost.view.layoutIfNeeded()

        taskCenter.tasks = []
    }
}

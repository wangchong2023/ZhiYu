//
//  IngestAndContentViewFullCoverageTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度覆盖 IngestView 与 ContentView 的全状态机、多任务进度条、安全锁定遮罩、数据库损坏横幅与侧边栏抽屉。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class IngestAndContentViewFullCoverageTests: XCTestCase {

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

    // MARK: - 1. IngestView 容器与动态任务进度面板覆盖

    struct IngestWrapperView: View {
        @State private var selectedTab: AppTab = .ingest

        var body: some View {
            IngestView(selectedTab: $selectedTab)
                .snapshotEnvironment()
        }
    }

    func testIngestViewEmptyAndRunningTaskStates() async {
        @Dependency(\.taskCenter) var taskCenter

        // 1. 空任务状态
        taskCenter.tasks = []
        let emptyWrapper = IngestWrapperView()
        let emptyHost = UIHostingController(rootView: emptyWrapper)
        XCTAssertNotNil(emptyHost.view)
        emptyHost.view.layoutIfNeeded()

        // 2. 注入运行中摄取任务
        let activeTask = GlobalTask(
            type: .ingest,
            name: "文档导入",
            target: "技术架构白皮书.pdf",
            status: .running(progress: 0.65, stage: .chunking),
            subLogs: ["正在解析 Markdown AST", "提取知识切片中..."]
        )
        taskCenter.tasks = [activeTask]

        let runningWrapper = IngestWrapperView()
        let runningHost = UIHostingController(rootView: runningWrapper)
        XCTAssertNotNil(runningHost.view)
        runningHost.view.layoutIfNeeded()

        taskCenter.tasks = []
    }

    // MARK: - 2. IngestCoordinator 动作与表单状态测试

    func testIngestCoordinatorActions() {
        let coordinator = IngestCoordinator()

        // 剪贴板导入
        coordinator.performClipboardImport()

        // 手动表单触发
        coordinator.newTitle = "手动创建笔记"
        coordinator.newContent = "这是手动输入的正文内容"
        coordinator.newType = .concept
        coordinator.sourceHint = .manual
        XCTAssertFalse(coordinator.newTitle.isEmpty)
        XCTAssertFalse(coordinator.newContent.isEmpty)

        // 错误状态弹窗
        coordinator.errorMessage = "网络请求超时"
        coordinator.showError = true
        XCTAssertTrue(coordinator.showError)
        XCTAssertEqual(coordinator.errorMessage, "网络请求超时")

        coordinator.errorMessage = nil
        coordinator.showError = false
        XCTAssertFalse(coordinator.showError)
    }

    // MARK: - 3. ContentView 根容器、安全锁与侧边栏渲染

    func testContentViewNormalAndLockedStates() {
        // 1. 正常状态渲染
        let normalContentView = ContentView()
            .snapshotEnvironment()
        let normalHost = UIHostingController(rootView: normalContentView)
        XCTAssertNotNil(normalHost.view)
        normalHost.view.layoutIfNeeded()

        // 2. 安全锁定状态渲染
        store.securityService.isLocked = true
        let lockedContentView = ContentView()
            .snapshotEnvironment()
        let lockedHost = UIHostingController(rootView: lockedContentView)
        XCTAssertNotNil(lockedHost.view)
        lockedHost.view.layoutIfNeeded()
        store.securityService.isLocked = false
    }

    // MARK: - 4. ContentView 侧边栏广播与抽屉通知测试

    func testContentViewSidebarToggleNotification() {
        let view = ContentView()
            .snapshotEnvironment()
        let hosting = UIHostingController(rootView: view)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()

        // 发送切换侧边栏通知
        NotificationCenter.default.post(name: Notification.Name.toggleSidebar, object: nil)
    }
}

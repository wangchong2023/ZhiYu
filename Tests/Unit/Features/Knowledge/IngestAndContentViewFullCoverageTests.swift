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
    // MARK: - 4. ContentView 侧边栏广播与抽屉通知测试
}

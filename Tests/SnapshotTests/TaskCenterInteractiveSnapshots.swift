//
//  TaskCenterInteractiveSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Snapshot] 快照测试层
//  核心职责：任务中心 (TaskCenterView)、异步任务看板与运行态卡片的视觉快照与渲染回归。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class TaskCenterInteractiveSnapshots: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 任务中心空状态看板快照

    func testTaskCenterView_EmptyState_RendersDashboardAndCards() {
        let view = NavigationStack {
            TaskCenterView()
        }
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. 任务中心包含运行中与已完成任务的列表快照

    func testTaskCenterView_WithActiveTasks_RendersList() {
        let taskCenter = TaskCenter()
        taskCenter.tasks.removeAll()

        let task1 = GlobalTask(
            type: .synthesis,
            name: "微服务架构脑图深度合成",
            target: "知识库合成",
            status: .running(progress: 0.65, stage: .enrichment),
            isRead: false
        )
        let task2 = GlobalTask(
            type: .ingest,
            name: "WWDC26 深度学习文档切片",
            target: "文档导入",
            status: .completed,
            isRead: true
        )
        taskCenter.tasks = [task1, task2]

        let view = NavigationStack {
            TaskCenterView()
        }
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}

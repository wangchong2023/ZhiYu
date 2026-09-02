//
//  TaskCenterInteractiveSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Snapshot] 快照测试层
//  核心职责：任务调度中心 (TaskCenterView)、实时任务进度卡与仪表板状态的视觉快照与渲染回归。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class TaskCenterInteractiveSnapshots: XCTestCase {

    private static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }

    override func invokeTest() {
        withSnapshotTesting(record: Self.recordMode) {
            super.invokeTest()
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        @Dependency(\.taskCenter) var taskCenter
        (taskCenter as? TaskCenter)?.reset()
    }

    // MARK: - 1. 任务中心主页空状态快照

    func testTaskCenterView_EmptyState_RendersDashboardAndCards() {
        let view = NavigationStack {
            TaskCenterView()
        }
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.relaxedPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. 任务列表活动中状态快照

    func testTaskCenterView_WithActiveTasks_RendersList() {
        @Dependency(\.taskCenter) var taskCenter
        let taskId = taskCenter.addTask(
            type: .ingest,
            name: "摄取任务",
            target: "《Karpathy LLM OS 论文》"
        )
        taskCenter.updateTask(taskId, status: .running(progress: 0.65, stage: .embedding))

        let view = NavigationStack {
            TaskCenterView()
        }
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}

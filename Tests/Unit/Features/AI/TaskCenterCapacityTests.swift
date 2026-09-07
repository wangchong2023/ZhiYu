//
//  TaskCenterCapacityTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - AI
//  核心职责：验证 TaskCenter 任务队列添加任务时超过上限容量的修剪机制与新任务置顶策略。
//

import XCTest
@testable import ZhiYu

final class TaskCenterCapacityTests: XCTestCase {

    /// 验证 addTask 在超过上限时自动修剪最旧任务
    @MainActor
    func testAddTask_exceedsCapacity_trimsOldestTasks() {
        let taskCenter = TaskCenter()
        taskCenter.tasks = []

        let maxTasks = FeatureConstants.TaskCenter.maxRetainedTasks
        let totalToAdd = maxTasks + 5

        for i in 0..<totalToAdd {
            _ = taskCenter.addTask(
                type: .ai,
                name: "Task\(i)",
                target: "target\(i)"
            )
        }

        XCTAssertLessThanOrEqual(
            taskCenter.tasks.count,
            maxTasks,
            "任务数不应超过 maxRetainedTasks"
        )

        if let firstTask = taskCenter.tasks.first {
            XCTAssertTrue(
                firstTask.name.contains("Task\(totalToAdd - 1)"),
                "最新添加的任务应在列表最前"
            )
        }
    }

    /// 验证在容量限制内的任务添加不进行修剪
    @MainActor
    func testAddTask_withinCapacity_retainsAllTasks() {
        let taskCenter = TaskCenter()
        taskCenter.tasks = []

        let maxTasks = FeatureConstants.TaskCenter.maxRetainedTasks

        for i in 0..<maxTasks {
            _ = taskCenter.addTask(
                type: .ai,
                name: "Task\(i)",
                target: "target\(i)"
            )
        }

        XCTAssertEqual(
            taskCenter.tasks.count,
            maxTasks,
            "刚好等于上限时不应清理"
        )
    }
}

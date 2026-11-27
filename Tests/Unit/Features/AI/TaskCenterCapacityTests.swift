//
//  TaskCenterCapacityTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - AI
//  核心职责：验证 TaskCenter 任务队列添加任务时超过上限容量的修剪机制与新任务置顶策略。
//

import XCTest
@testable import ZhiYuUnitTestHost

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

    // MARK: - 缺陷 #201 回归：末尾存在运行中任务时仍能裁剪中间历史任务 & 切换 Vault 自动清空任务

    @MainActor
    func testTrimExcessTasks_runningTaskAtTailDoesNotBlockTrimmingCompletedTasks() {
        let taskCenter = TaskCenter()
        taskCenter.tasks = []
        let maxTasks = FeatureConstants.TaskCenter.maxRetainedTasks

        // 最旧任务（位于数组末尾）处于 running 状态
        let oldestRunningID = taskCenter.addTask(type: .ai, name: "StickyRunning", target: "t0")
        taskCenter.updateTask(oldestRunningID, status: .running(progress: 0.5, stage: .general))

        // 继续添加超出容量上限的已完成/挂起任务
        for i in 1...(maxTasks + 4) {
            let id = taskCenter.addTask(type: .ai, name: "History\(i)", target: "t\(i)")
            taskCenter.completeTask(id: id)
        }

        XCTAssertLessThanOrEqual(
            taskCenter.tasks.count,
            maxTasks,
            "末尾存在运行中任务时，仍应跳过它继续裁剪其他非运行中历史任务"
        )
        XCTAssertTrue(
            taskCenter.tasks.contains { $0.id == oldestRunningID },
            "运行中的任务本身必须受到保护不被裁剪"
        )
    }

    @MainActor
    func testVaultWillSwitch_resetsTaskCenterState() async {
        let taskCenter = TaskCenter()
        _ = taskCenter.addTask(type: .ai, name: "VaultATask", target: "SecretDoc")
        XCTAssertFalse(taskCenter.tasks.isEmpty)

        NotificationCenter.default.post(name: .vaultWillSwitch, object: nil)
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(taskCenter.tasks.isEmpty, "切换 Vault 时必须清空旧库任务列表，防止跨库残留")
        XCTAssertTrue(taskCenter.latestStatus.isEmpty)
    }
}

//
//  TaskCenterTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//
//  系统层级：[L3] 测试层
//  核心职责：验证 TaskCenter 任务生命周期、状态流转、子日志、已读标记逻辑。
//

import Testing
import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class TaskCenterTests: XCTestCase {
    private var center: TaskCenter!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        center = TaskCenter()
        center.reset()
    }

    override func tearDown() async throws {
        center.reset()
        center = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialTasksEmpty() {
        XCTAssertTrue(center.tasks.isEmpty)
    }

    func testInitialLatestStatusEmpty() {
        XCTAssertTrue(center.latestStatus.isEmpty)
    }

    func testInitialUnreadCountZero() {
        XCTAssertEqual(center.unreadCount, 0)
    }

    // MARK: - TaskType

    func testTaskTypeIconNonEmpty() {
        for type in TaskType.allCases {
            XCTAssertFalse(type.icon.isEmpty)
        }
    }

    func testTaskTypeDefaultColorNonEmpty() {
        for type in TaskType.allCases {
            XCTAssertFalse(type.defaultColor.isEmpty)
        }
    }

    func testTaskTypeLocalizedNameNonEmpty() {
        for type in TaskType.allCases {
            XCTAssertFalse(type.localizedName.isEmpty)
        }
    }

    // MARK: - TaskStatus Equatable

    func testTaskStatusPendingEqual() {
        XCTAssertEqual(TaskStatus.pending, TaskStatus.pending)
    }

    func testTaskStatusCompletedEqual() {
        XCTAssertEqual(TaskStatus.completed, TaskStatus.completed)
    }

    func testTaskStatusRunningEqual() {
        XCTAssertEqual(TaskStatus.running(progress: 0.5, stage: .extraction),
                       TaskStatus.running(progress: 0.5, stage: .extraction))
    }

    func testTaskStatusRunningNotEqualDifferentProgress() {
        XCTAssertNotEqual(TaskStatus.running(progress: 0.5, stage: .extraction),
                          TaskStatus.running(progress: 0.6, stage: .extraction))
    }

    func testTaskStatusFailedEqual() {
        XCTAssertEqual(TaskStatus.failed(error: "err"), TaskStatus.failed(error: "err"))
    }

    func testTaskStatusFailedNotEqualDifferentError() {
        XCTAssertNotEqual(TaskStatus.failed(error: "err1"), TaskStatus.failed(error: "err2"))
    }

    // MARK: - addTask

    func testAddTaskInsertsAtFront() {
        let id1 = center.addTask(name: "任务1", target: "目标1")
        let id2 = center.addTask(name: "任务2", target: "目标2")

        XCTAssertEqual(center.tasks.count, 2)
        XCTAssertEqual(center.tasks.first?.id, id2)
        XCTAssertEqual(center.tasks.last?.id, id1)
    }

    func testAddTaskReturnsUniqueID() {
        let id1 = center.addTask(name: "任务1", target: "目标1")
        let id2 = center.addTask(name: "任务2", target: "目标2")

        XCTAssertNotEqual(id1, id2)
    }

    func testAddTaskSetsPendingStatus() {
        let id = center.addTask(name: "任务", target: "目标")

        XCTAssertEqual(center.tasks.first?.status, .pending)
        XCTAssertEqual(center.tasks.first?.id, id)
    }

    func testAddTaskUpdatesLatestStatus() {
        _ = center.addTask(name: "任务", target: "目标")

        XCTAssertFalse(center.latestStatus.isEmpty)
    }

    // MARK: - updateTask

    func testUpdateTaskToRunning() {
        let id = center.addTask(name: "任务", target: "目标")

        center.updateTask(id, status: .running(progress: 0.5, stage: .extraction))

        XCTAssertEqual(center.tasks.first?.status, .running(progress: 0.5, stage: .extraction))
    }

    func testUpdateTaskToCompleted() {
        let id = center.addTask(name: "任务", target: "目标")

        center.updateTask(id, status: .completed)

        XCTAssertEqual(center.tasks.first?.status, .completed)
    }

    func testUpdateTaskToFailed() {
        let id = center.addTask(name: "任务", target: "目标")

        center.updateTask(id, status: .failed(error: "测试错误"))

        XCTAssertEqual(center.tasks.first?.status, .failed(error: "测试错误"))
    }

    func testUpdateTaskWithAssociatedPageID() {
        let id = center.addTask(name: "任务", target: "目标")
        let pageID = UUID()

        center.updateTask(id, status: .completed, associatedPageID: pageID)

        XCTAssertEqual(center.tasks.first?.associatedPageID, pageID)
    }

    func testUpdateTaskNonExistentIDNoOp() {
        center.updateTask(UUID(), status: .completed)

        XCTAssertTrue(center.tasks.isEmpty)
    }

    // MARK: - completeTask / failTask

    func testCompleteTask() {
        let id = center.addTask(name: "任务", target: "目标")

        center.completeTask(id: id)

        XCTAssertEqual(center.tasks.first?.status, .completed)
    }

    func testFailTask() {
        let id = center.addTask(name: "任务", target: "目标")

        center.failTask(id: id, error: "失败")

        XCTAssertEqual(center.tasks.first?.status, .failed(error: "失败"))
    }

    // MARK: - addSubLog

    func testAddSubLogAppendsLog() {
        let id = center.addTask(name: "任务", target: "目标")

        center.addSubLog(id: id, log: "日志1")
        center.addSubLog(id: id, log: "日志2")

        XCTAssertEqual(center.tasks.first?.subLogs.count, 2)
        XCTAssertEqual(center.tasks.first?.subLogs, ["日志1", "日志2"])
    }

    func testAddSubLogUpdatesLatestStatus() {
        let id = center.addTask(name: "任务", target: "目标")

        center.addSubLog(id: id, log: "子状态")

        XCTAssertTrue(center.latestStatus.contains("子状态"))
    }

    func testAddSubLogNonExistentIDNoOp() {
        center.addSubLog(id: UUID(), log: "日志")

        XCTAssertTrue(center.tasks.isEmpty)
    }

    func testAddSubLogTrimsAtMaxCount() {
        let id = center.addTask(name: "任务", target: "目标")

        for i in 0..<60 {
            center.addSubLog(id: id, log: "日志\(i)")
        }

        XCTAssertEqual(center.tasks.first?.subLogs.count, 50)
    }

    // MARK: - addIngestSubLog

    func testAddIngestSubLogAppendsToIngestTask() {
        let id = center.addTask(type: .ingest, name: "导入", target: "文件")

        center.addIngestSubLog("导入中")

        XCTAssertEqual(center.tasks.first?.subLogs.count, 1)
        XCTAssertEqual(center.tasks.first?.subLogs.first, "导入中")
        _ = id
    }

    func testAddIngestSubLogNoIngestTaskNoOp() {
        _ = center.addTask(type: .ai, name: "AI", target: "目标")

        center.addIngestSubLog("导入中")

        XCTAssertEqual(center.tasks.first?.subLogs.count, 0)
    }

    // MARK: - markAsRead / markAllAsRead

    func testMarkAsRead() {
        let id = center.addTask(name: "任务", target: "目标")
        center.completeTask(id: id)

        center.markAsRead(id)

        // markAsRead 用 DispatchQueue.main.async，需等待
        let exp = expectation(description: "markAsRead")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.center.tasks.first?.isRead ?? false)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testMarkAllAsRead() {
        let id1 = center.addTask(name: "任务1", target: "目标1")
        let id2 = center.addTask(name: "任务2", target: "目标2")
        center.completeTask(id: id1)
        center.failTask(id: id2, error: "err")

        center.markAllAsRead()

        XCTAssertTrue(center.tasks.allSatisfy { $0.isRead })
    }

    // MARK: - removeTask

    func testRemoveTask() {
        let id = center.addTask(name: "任务", target: "目标")

        center.removeTask(id)

        let exp = expectation(description: "removeTask")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.center.tasks.isEmpty)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - unreadCount

    func testUnreadCountCountsCompletedAndFailed() {
        let id1 = center.addTask(name: "任务1", target: "目标1")
        let id2 = center.addTask(name: "任务2", target: "目标2")
        center.completeTask(id: id1)
        center.failTask(id: id2, error: "err")

        XCTAssertEqual(center.unreadCount, 2)
    }

    func testUnreadCountExcludesPendingAndRunning() {
        let id1 = center.addTask(name: "任务1", target: "目标1")
        let id2 = center.addTask(name: "任务2", target: "目标2")
        _ = id1
        center.updateTask(id2, status: .running(progress: 0.5, stage: .extraction))

        XCTAssertEqual(center.unreadCount, 0)
    }

    func testUnreadCountExcludesRead() {
        let id1 = center.addTask(name: "任务1", target: "目标1")
        center.completeTask(id: id1)
        center.markAllAsRead()

        XCTAssertEqual(center.unreadCount, 0)
    }

    // MARK: - metrics

    func testMetricsForType() {
        let id1 = center.addTask(type: .ingest, name: "导入1", target: "文件1")
        let id2 = center.addTask(type: .ingest, name: "导入2", target: "文件2")
        let id3 = center.addTask(type: .ai, name: "AI", target: "目标")
        center.completeTask(id: id1)
        center.failTask(id: id2, error: "err")
        _ = id3

        let metrics = center.metrics(for: .ingest)

        XCTAssertEqual(metrics.total, 2)
        XCTAssertEqual(metrics.completed, 1)
        XCTAssertEqual(metrics.failed, 1)
        XCTAssertEqual(metrics.running, 0)
    }

    func testMetricsForTypeNoTasks() {
        let metrics = center.metrics(for: .ai)

        XCTAssertEqual(metrics.total, 0)
        XCTAssertEqual(metrics.completed, 0)
        XCTAssertEqual(metrics.running, 0)
        XCTAssertEqual(metrics.failed, 0)
    }

    // MARK: - updateLatestStatus

    func testUpdateLatestStatusUpdatesText() {
        center.updateLatestStatus("新状态")

        XCTAssertEqual(center.latestStatus, "新状态")
    }

    // MARK: - reset

    func testResetClearsTasks() {
        _ = center.addTask(name: "任务", target: "目标")

        center.reset()

        XCTAssertTrue(center.tasks.isEmpty)
    }

    func testResetClearsLatestStatus() {
        center.latestStatus = "状态"

        center.reset()

        XCTAssertTrue(center.latestStatus.isEmpty)
    }

    // MARK: - 任务上限

    func testCompletedTaskTrimsAt20() {
        for i in 0..<25 {
            let id = center.addTask(name: "任务\(i)", target: "目标")
            center.completeTask(id: id)
        }

        XCTAssertLessThanOrEqual(center.tasks.count, 20)
    }
}

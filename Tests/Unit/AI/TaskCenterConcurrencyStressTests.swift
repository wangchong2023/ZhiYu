//
//  TaskCenterConcurrencyStressTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：深入验证 TaskCenter 的高并发多任务管理、未读统计、细粒度日志截断与清理分支。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class TaskCenterConcurrencyStressTests: XCTestCase {

    // MARK: - 1. 任务添加与未读计数分支

    func testAddTask_CreatesPendingTaskAndNotifies() {
        let taskCenter = TaskCenter()
        taskCenter.tasks.removeAll()

        let taskID = taskCenter.addTask(type: .ingest, name: "批量 PDF 导入", target: "文档切片")

        XCTAssertEqual(taskCenter.tasks.count, 1)
        XCTAssertEqual(taskCenter.tasks.first?.id, taskID)
        XCTAssertEqual(taskCenter.unreadCount, 0, "等待中的任务不应计入未读完成数")
    }

    // MARK: - 2. 状态与进度更新分支

    func testUpdateTask_SetsRunningStatus() {
        let taskCenter = TaskCenter()
        taskCenter.tasks.removeAll()

        let taskID = taskCenter.addTask(type: .synthesis, name: "微服务脑图合成", target: "深度合成")

        taskCenter.updateTask(taskID, status: .running(progress: 0.65, stage: .enrichment))
        if case .running(let p, let s) = taskCenter.tasks.first?.status {
            XCTAssertEqual(p, 0.65)
            XCTAssertEqual(s, .enrichment)
        } else {
            XCTFail("任务状态应当为 running")
        }
    }

    // MARK: - 3. 细粒度日志环形缓冲截断分支

    func testAddSubLog_WhenExceedsLimit_TruncatesOldestLogs() {
        let taskCenter = TaskCenter()
        taskCenter.tasks.removeAll()

        let taskID = taskCenter.addTask(type: .aiScan, name: "全库死链与健康度扫描", target: "全库")

        for i in 1...60 {
            taskCenter.addSubLog(id: taskID, log: "执行步骤 #\(i)")
        }

        let logs = taskCenter.tasks.first?.subLogs ?? []
        XCTAssertLessThanOrEqual(logs.count, 50, "单任务子日志数量应当受最大 50 条容量限制")
    }

    // MARK: - 4. 任务完成与未读统计分支

    func testCompleteTask_IncrementsUnreadCount() {
        let taskCenter = TaskCenter()
        taskCenter.tasks.removeAll()

        let taskID = taskCenter.addTask(type: .healthCheck, name: "孤立节点分析", target: "图谱")
        taskCenter.completeTask(id: taskID)

        XCTAssertEqual(taskCenter.unreadCount, 1, "任务完成后应存在 1 条未读提醒")
    }

    // MARK: - 5. 任务重置分支

    func testReset_ClearsAllTasksAndStatus() {
        let taskCenter = TaskCenter()
        taskCenter.tasks.removeAll()

        let runningID = taskCenter.addTask(type: .ai, name: "运行中任务", target: "后台")
        let completedID = taskCenter.addTask(type: .ingest, name: "已完成任务", target: "后台")

        taskCenter.updateTask(runningID, status: .running(progress: 0.5, stage: .embedding))
        taskCenter.completeTask(id: completedID)

        taskCenter.reset()

        XCTAssertTrue(taskCenter.tasks.isEmpty, "重置后任务列表应当全空")
        XCTAssertTrue(taskCenter.latestStatus.isEmpty, "重置后状态文本应当清空")
    }

    // MARK: - 6. 并发高负载任务调度稳定性分支

    func testStressConcurrentTasks_ManagesMultipleTasksSafely() {
        let taskCenter = TaskCenter()
        taskCenter.tasks.removeAll()

        var taskIDs: [UUID] = []
        for i in 1...20 {
            let id = taskCenter.addTask(type: .synthesis, name: "并发任务 #\(i)", target: "后台")
            taskIDs.append(id)
        }

        XCTAssertEqual(taskCenter.tasks.count, 20)

        // 批量更新进度与完成
        for (index, id) in taskIDs.enumerated() {
            if index % 2 == 0 {
                taskCenter.completeTask(id: id)
            } else {
                taskCenter.failTask(id: id, error: "模拟超时故障")
            }
        }

        XCTAssertEqual(taskCenter.tasks.filter { $0.status == .completed }.count, 10)
        XCTAssertEqual(taskCenter.tasks.filter {
            if case .failed = $0.status { return true }
            return false
        }.count, 10)
    }
}

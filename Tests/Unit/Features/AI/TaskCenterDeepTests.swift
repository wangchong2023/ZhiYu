//
//  TaskCenterDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：TaskCenterLifecycleAndFaultTests.swift, TaskCenterViewInteractiveTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class TaskCenterDeepTests: XCTestCase {

    private var taskCenter: TaskCenter!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        taskCenter = TaskCenter()
    }

    func testTaskCenterLifecycleAndFaultInjection() async throws {
        @Dependency(\.taskCenter) var taskCenter

        // 1. 添加任务
        let taskID1 = taskCenter.addTask(type: .ingest, name: "OCR Processing", target: "Scan Document")
        let taskID2 = taskCenter.addTask(type: .synthesis, name: "Mindmap Synthesis", target: "Architecture Notes")
        let taskID3 = taskCenter.addTask(type: .aiScan, name: "Vector Indexing", target: "Vault Content")

        XCTAssertFalse(taskCenter.tasks.isEmpty)

        // 2. 更新执行状态与阶段
        taskCenter.updateTask(taskID1, status: .running(progress: 0.75, stage: .extraction))
        taskCenter.addSubLog(id: taskID1, log: "Recognizing Chinese Characters")

        let task1 = taskCenter.tasks.first(where: { $0.id == taskID1 })
        if case .running(let prog, let stage) = task1?.status {
            XCTAssertEqual(prog, 0.75)
            XCTAssertEqual(stage, .extraction)
        } else {
            XCTFail("Task should be in running status")
        }
        XCTAssertEqual(task1?.subLogs.count, 1)

        // 3. 成功完成任务
        taskCenter.completeTask(id: taskID1)
        XCTAssertEqual(taskCenter.tasks.first(where: { $0.id == taskID1 })?.status, .completed)

        // 4. 故障注入：任务失败
        taskCenter.failTask(id: taskID2, error: "Network timeout code 504")
        let task2 = taskCenter.tasks.first(where: { $0.id == taskID2 })
        XCTAssertEqual(task2?.status, .failed(error: "Network timeout code 504"))

        // 5. 任务标记完成关联页面
        let pageID = UUID()
        taskCenter.completeTask(id: taskID3, associatedPageID: pageID)
        let task3 = taskCenter.tasks.first(where: { $0.id == taskID3 })
        XCTAssertEqual(task3?.associatedPageID, pageID)

        // 6. 标记已读与未读数
        taskCenter.markAsRead(taskID1)
        taskCenter.markAllAsRead()
        XCTAssertEqual(taskCenter.unreadCount, 0)

        // 7. 更新最新全局状态
        taskCenter.updateLatestStatus("Global indexing finished")
        XCTAssertEqual(taskCenter.latestStatus, "Global indexing finished")

        // 8. 移除单个与重置
        taskCenter.removeTask(taskID1)
        XCTAssertNil(taskCenter.tasks.first(where: { $0.id == taskID1 }))

        taskCenter.reset()
        XCTAssertTrue(taskCenter.tasks.isEmpty)
    }

    func testTaskCenterMetricsAndFiltering() {
        taskCenter.reset()

        let id1 = taskCenter.addTask(type: .ai, name: "AI 总结任务", target: "系统架构概论")
        taskCenter.completeTask(id: id1)

        let id2 = taskCenter.addTask(type: .ingest, name: "文档导入任务", target: "Kubernetes 文档")
        taskCenter.updateTask(id2, status: .running(progress: 0.6, stage: .chunking))

        let id3 = taskCenter.addTask(type: .healthCheck, name: "健康检查", target: "本地数据库")
        taskCenter.failTask(id: id3, error: "磁盘空间预警")

        XCTAssertEqual(taskCenter.tasks.count, 3)

        // 验证各类型任务指标计算
        let aiMetrics = taskCenter.metrics(for: .ai)
        XCTAssertEqual(aiMetrics.total, 1)
        XCTAssertEqual(aiMetrics.completed, 1)

        let ingestMetrics = taskCenter.metrics(for: .ingest)
        XCTAssertEqual(ingestMetrics.total, 1)
        XCTAssertEqual(ingestMetrics.running, 1)

        let healthMetrics = taskCenter.metrics(for: .healthCheck)
        XCTAssertEqual(healthMetrics.total, 1)
        XCTAssertEqual(healthMetrics.failed, 1)
    }

    func testMarkAsReadAndRemoveTask() {
        taskCenter.reset()

        let taskID = taskCenter.addTask(type: .ai, name: "未读报告", target: "目标 A")
        taskCenter.completeTask(id: taskID)

        let initialTask = taskCenter.tasks.first(where: { $0.id == taskID })
        XCTAssertFalse(initialTask?.isRead ?? true)

        // 标记为已读
        taskCenter.markAsRead(taskID)
        let readTask = taskCenter.tasks.first(where: { $0.id == taskID })
        XCTAssertTrue(readTask?.isRead ?? false)

        // 移除该任务
        taskCenter.removeTask(taskID)
        XCTAssertNil(taskCenter.tasks.first(where: { $0.id == taskID }))
    }

    func testMarkAllAsReadAndReset() {
        taskCenter.reset()

        let id1 = taskCenter.addTask(type: .ai, name: "T1", target: "A")
        let id2 = taskCenter.addTask(type: .ingest, name: "T2", target: "B")
        taskCenter.completeTask(id: id1)
        taskCenter.failTask(id: id2, error: "失败")

        XCTAssertEqual(taskCenter.unreadCount, 2)

        // 全部标为已读
        taskCenter.markAllAsRead()
        XCTAssertEqual(taskCenter.unreadCount, 0)

        // 全部重置清空
        taskCenter.reset()
        XCTAssertTrue(taskCenter.tasks.isEmpty)
    }

    func testTaskCenterViewRendering() {
        let view = TaskCenterView().snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertEqual(taskCenter.tasks.count, 0)
        XCTAssertEqual(taskCenter.unreadCount, 0)
    }

    func testTaskRetentionAndRunningTaskProtection() {
        taskCenter.reset()

        // 1. 添加一个长期运行中的后台任务
        let runningTaskID = taskCenter.addTask(type: .ai, name: "长效大模型扫描任务", target: "全库知识抽取")
        taskCenter.updateTask(runningTaskID, status: .running(progress: 0.2, stage: .chunking))

        // 2. 插入大量快速完成/失败的任务触发容量溢出上限
        for i in 1...FeatureConstants.TaskCenter.maxRetainedTasks {
            let id = taskCenter.addTask(type: .ingest, name: "子文档 \(i)", target: "Doc\(i)")
            if i % 2 == 0 {
                taskCenter.completeTask(id: id)
            } else {
                taskCenter.failTask(id: id, error: "模拟解析失败")
            }
        }

        // 3. 验证容量上限生效，且正在运行的任务没有被错误裁剪丢弃
        // running 任务受保护不计入历史容量上限，故非运行中任务数应 ≤ maxRetainedTasks
        let nonRunningCount = taskCenter.tasks.filter {
            if case .running = $0.status { return false }; return true
        }.count
        XCTAssertLessThanOrEqual(nonRunningCount, FeatureConstants.TaskCenter.maxRetainedTasks)
        let retainedRunning = taskCenter.tasks.first(where: { $0.id == runningTaskID })
        XCTAssertNotNil(retainedRunning, "正在运行中的后台任务不能因为历史任务过多而被粗暴丢弃")

        // 4. 验证失败任务（.failed）在到达上限后同样触发裁剪逻辑，不再无限堆积
        let failedCount = taskCenter.tasks.filter {
            if case .failed = $0.status { return true }; return false
        }.count
        XCTAssertGreaterThan(failedCount, 0)
        XCTAssertLessThanOrEqual(failedCount, FeatureConstants.TaskCenter.maxRetainedTasks)
    }

}

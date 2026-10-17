//
//  TaskModelsTests.swift
//  ZhiYuDomainTests
//
//  Created by CodeFree on 2026/08/10.
//
//  系统层级：[ZhiYuDomain] 测试层
//  核心职责：验证 TaskStatus / TaskStage 任务模型的纯逻辑行为（判等与阶段枚举），
//           抽取自 App 层 TaskCenterTests，仅含不依赖 TaskCenter 服务调度与 UI/L10n 的模型用例。
//

import XCTest
@testable import ZhiYuDomain

final class TaskModelsTests: XCTestCase {

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

    func testTaskStatusRunningNotEqualDifferentStage() {
        XCTAssertNotEqual(TaskStatus.running(progress: 0.5, stage: .extraction),
                          TaskStatus.running(progress: 0.5, stage: .enrichment))
    }

    func testTaskStatusFailedEqual() {
        XCTAssertEqual(TaskStatus.failed(error: "err"), TaskStatus.failed(error: "err"))
    }

    func testTaskStatusFailedNotEqualDifferentError() {
        XCTAssertNotEqual(TaskStatus.failed(error: "err1"), TaskStatus.failed(error: "err2"))
    }

    func testTaskStatusPendingNotEqualRunning() {
        XCTAssertNotEqual(TaskStatus.pending, TaskStatus.running(progress: 0, stage: .general))
    }

    func testTaskStatusCompletedNotEqualFailed() {
        XCTAssertNotEqual(TaskStatus.completed, TaskStatus.failed(error: "err"))
    }

    // MARK: - TaskStage 枚举完备性

    func testTaskStageRawValues() {
        XCTAssertEqual(TaskStage.pending.rawValue, "pending")
        XCTAssertEqual(TaskStage.extraction.rawValue, "extraction")
        XCTAssertEqual(TaskStage.enrichment.rawValue, "enrichment")
        XCTAssertEqual(TaskStage.chunking.rawValue, "chunking")
        XCTAssertEqual(TaskStage.embedding.rawValue, "embedding")
        XCTAssertEqual(TaskStage.retrieval.rawValue, "retrieval")
        XCTAssertEqual(TaskStage.synthesis.rawValue, "synthesis")
        XCTAssertEqual(TaskStage.general.rawValue, "general")
    }

    // MARK: - GlobalTask 模型

    func testGlobalTaskInitAndDefaults() {
        let task = GlobalTask(type: .ingest, name: "导入", target: "文档.md", status: .pending)
        XCTAssertEqual(task.type, .ingest)
        XCTAssertEqual(task.name, "导入")
        XCTAssertEqual(task.target, "文档.md")
        XCTAssertEqual(task.status, .pending)
        XCTAssertFalse(task.isRead)
        XCTAssertNil(task.associatedPageID)
        XCTAssertTrue(task.subLogs.isEmpty)
    }

    func testGlobalTaskFieldsEqual() {
        let t1 = GlobalTask(type: .ai, name: "任务", target: "目标", status: .running(progress: 0.3, stage: .embedding))
        let t2 = GlobalTask(type: .ai, name: "任务", target: "目标", status: .running(progress: 0.3, stage: .embedding))
        XCTAssertEqual(t1.type, t2.type)
        XCTAssertEqual(t1.name, t2.name)
        XCTAssertEqual(t1.target, t2.target)
        XCTAssertEqual(t1.status, t2.status)
    }

    func testGlobalTaskStatusMutable() {
        var task = GlobalTask(type: .ai, name: "任务", target: "目标", status: .pending)
        task.status = .completed
        task.isRead = true
        XCTAssertEqual(task.status, .completed)
        XCTAssertTrue(task.isRead)
    }
}
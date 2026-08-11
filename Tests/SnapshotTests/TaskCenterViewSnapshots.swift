//
//  TaskCenterViewSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：TaskCenter View 的快照测试，覆盖空状态、有任务状态、不同任务类型与状态组合。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class TaskCenterViewSnapshots: XCTestCase {

    /// 依据环境变量判断快照录制策略
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
        // 清空 TaskCenter 单例，确保空状态测试不受残留任务影响
        TaskCenter.shared.reset()
    }

    override func tearDown() async throws {
        TaskCenter.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 测试数据工厂

    /// 构造已完成任务
    private func makeCompletedTask(type: TaskType = .ai, name: String = "AI 语义扫描") -> GlobalTask {
        GlobalTask(type: type, name: name, target: "知识库/机器学习.md", status: .completed)
    }

    /// 构造运行中任务（带进度）
    private func makeRunningTask(progress: Double = 0.5, type: TaskType = .ingest) -> GlobalTask {
        GlobalTask(type: type, name: "导入文档", target: "论文.pdf", status: .running(progress: progress, stage: .extraction))
    }

    /// 构造失败任务
    private func makeFailedTask(error: String = "网络连接超时") -> GlobalTask {
        GlobalTask(type: .aiScan, name: "健康检查", target: "全库", status: .failed(error: error))
    }

    /// 构造待处理任务
    private func makePendingTask() -> GlobalTask {
        GlobalTask(type: .synthesis, name: "知识合成", target: "概念图", status: .pending)
    }

    // MARK: - 快照测试

    /// 测试空状态 — 无任务时的引导界面
    func testTaskCenterView_EmptyState() {
        let view = makeTaskCenterView()
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试有任务状态 — 包含多种类型与状态的任务列表
    func testTaskCenterView_WithTasks() {
        TaskCenter.shared.tasks = [
            makeCompletedTask(),
            makeRunningTask(progress: 0.3),
            makeFailedTask(),
            makePendingTask()
        ]
        let view = makeTaskCenterView()
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试全部完成的稳定状态
    func testTaskCenterView_AllCompleted() {
        TaskCenter.shared.tasks = [
            makeCompletedTask(type: .ai, name: "AI 扫描完成"),
            makeCompletedTask(type: .ingest, name: "文档导入完成"),
            makeCompletedTask(type: .healthCheck, name: "健康检查完成"),
            makeCompletedTask(type: .synthesis, name: "知识合成完成")
        ]
        let view = makeTaskCenterView()
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试运行中状态 — 展示进度条与运行中指标
    func testTaskCenterView_RunningState() {
        TaskCenter.shared.tasks = [
            makeRunningTask(progress: 0.2, type: .ingest),
            makeRunningTask(progress: 0.7, type: .aiScan),
            makeRunningTask(progress: 0.9, type: .synthesis)
        ]
        let view = makeTaskCenterView()
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试失败状态 — 展示错误信息
    func testTaskCenterView_FailedState() {
        TaskCenter.shared.tasks = [
            makeFailedTask(error: "网络连接超时"),
            GlobalTask(type: .synthesis, name: "合成失败", target: "概念图", status: .failed(error: "LLM 响应异常")),
            GlobalTask(type: .ingest, name: "导入失败", target: "损坏文件.pdf", status: .failed(error: "文件格式不支持"))
        ]
        let view = makeTaskCenterView()
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试已读状态 — 已读任务半透明
    func testTaskCenterView_ReadTasks() {
        var completedTask = makeCompletedTask()
        completedTask.isRead = true
        var failedTask = makeFailedTask()
        failedTask.isRead = true
        TaskCenter.shared.tasks = [completedTask, failedTask]
        let view = makeTaskCenterView()
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试关联页面任务 — 展示跳转图标
    func testTaskCenterView_WithAssociatedPage() {
        var task = makeCompletedTask()
        task.associatedPageID = UUID()
        TaskCenter.shared.tasks = [task]
        let view = makeTaskCenterView()
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 视图工厂

    /// 构造 TaskCenterView 并注入所需环境依赖
    /// 使用 `.snapshotEnvironment()` 统一注入全量 @Environment 依赖，杜绝遗漏
    private func makeTaskCenterView() -> some View {
        TaskCenterView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)
    }
}

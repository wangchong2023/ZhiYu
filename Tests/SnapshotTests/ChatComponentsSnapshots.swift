//
//  ChatComponentsSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：Chat 组件快照测试，覆盖 AIPulseIndicator 脉搏指示器与 ChatWelcomeView 欢迎页。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ChatComponentsSnapshots: XCTestCase {

    @Dependency(\.taskCenter) var taskCenter

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
        // 清空 TaskCenter 单例，确保 AIPulseIndicator 空闲状态
        taskCenter.reset()
    }

    override func tearDown() async throws {
        taskCenter.reset()
        try await super.tearDown()
    }

    // MARK: - AIPulseIndicator 快照测试

    /// 测试 AIPulseIndicator 空闲状态 — 无 AI 任务运行
    func testAIPulseIndicator_Idle() {
        let view = AIPulseIndicator()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 AIPulseIndicator AI 处理中状态 — 有运行中 AI 任务
    func testAIPulseIndicator_AIProcessing() {
        taskCenter.tasks = [
            GlobalTask(type: .ai, name: "AI 扫描", target: "全库", status: .running(progress: 0.5, stage: .synthesis))
        ]
        let view = AIPulseIndicator()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 AIPulseIndicator 向量化阶段 — embedding 阶段颜色
    func testAIPulseIndicator_EmbeddingStage() {
        taskCenter.tasks = [
            GlobalTask(type: .ai, name: "向量化", target: "文档", status: .running(progress: 0.3, stage: .embedding))
        ]
        let view = AIPulseIndicator()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    // MARK: - ChatWelcomeView 快照测试

    /// 测试 Chat 欢迎页 — 默认状态（非 Sheet 模式）
    func testChatWelcomeView_Default() {
        let view = ChatWelcomeView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试 Chat 欢迎页 — Sheet 模式
    func testChatWelcomeView_SheetMode() {
        let view = ChatWelcomeView(isSheet: true)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}

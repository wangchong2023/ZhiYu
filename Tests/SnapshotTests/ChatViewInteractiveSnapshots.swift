//
//  ChatViewInteractiveSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All agreed.
//
//  系统层级：[Snapshot] 快照测试层
//  核心职责：AI 对话视图 (ChatView)、气泡排版与多轮交互状态的视觉快照与渲染回归。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class ChatViewInteractiveSnapshots: XCTestCase {

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
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        store.pages = []
        ServiceContainer.shared.resolveOptional(TaskCenter.self)?.reset()
    }

    // MARK: - 1. ChatView 完整交互容器（空状态引导）

    func testChatView_EmptyState_RendersPlaceholderGuide() {
        let view = NavigationStack {
            ChatView(selectedTab: .constant(.chat))
        }
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.relaxedPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. 用户提问气泡（渐变主色卡片）

    func testChatBubble_UserMessage_RendersGradientCard() {
        let bubble = AIChatBubbleView(
            text: "请帮我总结一下关于分布式系统 Paxos 共识算法的核心两阶段提交逻辑。",
            isUser: true
        )
        .padding()
        .snapshotEnvironment()

        assertSnapshot(of: bubble, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize)))
    }

    // MARK: - 3. AI 思考中与回答卡片

    func testChatBubble_AssistantWithThinking_RendersCollapsibleCard() {
        let bubble = AIChatBubbleView(
            text: "Paxos 算法的核心是二阶段提交（Prepare/Promise 与 Accept/Accepted）",
            isUser: false
        )
        .padding()
        .snapshotEnvironment()

        assertSnapshot(of: bubble, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize)))
    }
}

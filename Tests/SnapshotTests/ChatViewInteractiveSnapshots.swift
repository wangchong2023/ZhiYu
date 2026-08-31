//
//  ChatViewInteractiveSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
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

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. ChatView 完整交互容器（空状态引导）

    func testChatView_EmptyState_RendersPlaceholderGuide() {
        let view = NavigationStack {
            ChatView(selectedTab: .constant(.chat))
        }
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. 用户提问气泡（渐变主色卡片）

    func testChatBubble_UserMessage_RendersGradientCard() {
        let message = ChatMessage(
            role: .user,
            content: "请帮我总结一下关于分布式系统 Paxos 共识算法的核心两阶段提交逻辑。"
        )
        let view = ChatBubbleView(
            message: message,
            pages: [],
            selectedTab: .constant(.chat)
        )
        .padding()
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize)))
    }

    // MARK: - 3. AI 助手 Markdown 与代码块复合气泡

    func testChatBubble_AssistantMarkdownCode_RendersSyntaxHighlighter() {
        let markdownContent = """
        ### Paxos 算法两阶段流程：
        
        1. **Prepare 阶段**：Proposer 提出编号 `n` 的 Proposal。
        2. **Accept 阶段**：超过半数 Acceptor 接受并确认。
        
        ```swift
        func prepare(proposalID: Int) async throws -> Promise {
            guard proposalID > minPromisedID else { throw PaxosError.rejected }
            minPromisedID = proposalID
            return Promise(acceptedID: lastAcceptedID, value: lastAcceptedValue)
        }
        ```
        """
        let message = ChatMessage(
            role: .assistant,
            content: markdownContent,
            relatedPageIDs: [UUID()]
        )
        let view = ChatBubbleView(
            message: message,
            pages: [KnowledgePage(title: "Paxos 共识机制笔记", content: "详细介绍")],
            selectedTab: .constant(.chat),
            predictedQuestions: ["Paxos 与 Raft 有什么本质区别？", "如何解决活锁问题？"]
        )
        .padding()
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotGraphViewportSize)))
    }

    // MARK: - 4. 批量多选模式气泡勾选态

    func testChatBubble_SelectionMode_RendersCheckboxes() {
        let message = ChatMessage(
            role: .user,
            content: "这是一条在多选模式下被选中的历史消息。"
        )
        let view = ChatBubbleView(
            message: message,
            pages: [],
            selectedTab: .constant(.chat),
            isSelectionMode: true,
            isSelected: true
        )
        .padding()
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }
}

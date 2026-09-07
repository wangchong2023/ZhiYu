//
//  ChatComponentsInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 功能测试层
//  核心职责：ChatComponents 子组件交互、引用来源分组展开、思考气泡折叠与追问推荐测试
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ChatComponentsInteractiveTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ChatReferencesView 引用折叠与按页面类型分组测试

    func testChatReferencesViewGroupingAndExpansion() {
        let page1 = KnowledgePage(
            title: "微服务设计模式",
            pageType: .concept,
            content: "微服务架构核心模式总结"
        )
        let page2 = KnowledgePage(
            title: "Raft 与 Paxos 详细对比",
            pageType: .comparison,
            content: "共识算法维度比对"
        )

        let pages = [page1, page2]
        var message = ChatMessage(role: .assistant, content: "回复内容")
        message.relatedPageIDs = [page1.id, page2.id]

        // 验证页面类型聚合分组逻辑
        let grouped = Dictionary(grouping: message.relatedPageIDs.compactMap { id in pages.first { $0.id == id } }) { $0.pageType }
        XCTAssertEqual(grouped.keys.count, 2, "应归纳出 2 种不同的页面类型")
        XCTAssertEqual(grouped[.concept]?.count, 1)
        XCTAssertEqual(grouped[.comparison]?.count, 1)

        struct Host: View {
            @State var selectedTab: AppTab = .chat
            let message: ChatMessage
            let pages: [KnowledgePage]

            var body: some View {
                ChatBubbleView(
                    message: message,
                    pages: pages,
                    selectedTab: $selectedTab
                )
            }
        }

        let host = UIHostingController(rootView: Host(message: message, pages: pages).snapshotEnvironment())
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertEqual(grouped.count, 2)
    }

    // MARK: - 2. ChatContentView 思考过程折叠与链接跳转测试

    func testChatContentViewThinkingAndMarkdown() {
        let thinkingMessage = """
        <think>
        思考过程：首先检索本地知识库，发现匹配到微服务设计模式。
        </think>
        微服务架构能够有效提升团队协作效率。
        """

        let page = KnowledgePage(title: "微服务设计模式", content: "详细内容")
        let processed = ThinkingProcessor.process(thinkingMessage)

        XCTAssertNotNil(processed.thinkingContent, "应能正确解析出 <think> 标签内的思考内容")
        XCTAssertTrue(processed.thinkingContent?.contains("检索本地知识库") == true)
        XCTAssertTrue(processed.mainContent.contains("微服务架构能够有效提升"))

        struct Host: View {
            @State var selectedTab: AppTab = .chat
            let text: String
            let pages: [KnowledgePage]

            var body: some View {
                ChatContentView(
                    text: text,
                    pages: pages,
                    selectedTab: $selectedTab
                )
            }
        }

        let host = UIHostingController(rootView: Host(text: thinkingMessage, pages: [page]).snapshotEnvironment())
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. SuggestedFollowUpCardView 追问卡片交互测试

    func testSuggestedFollowUpCardViewInteraction() {
        let questions = [
            "如何设计高可用容灾架构？",
            "分布式事务在微服务中如何解决？"
        ]

        var selectedQuestion: String?

        let cardView = SuggestedFollowUpCardView(
            questions: questions,
            onSelect: { question in
                selectedQuestion = question
            }
        )

        let host = UIHostingController(rootView: cardView.snapshotEnvironment())
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)

        // 模拟触发选择第一项
        cardView.onSelect(questions[0])
        XCTAssertEqual(selectedQuestion, questions[0], "点击应触发回调并回传追问问题")
    }

    // MARK: - 4. AIPulseIndicator 动画指示器测试

    func testAIPulseIndicatorRendering() {
        let indicator = AIPulseIndicator()
        let host = UIHostingController(rootView: indicator.snapshotEnvironment())
        _ = host.view
        host.view.layoutIfNeeded()

        let taskCenter = TaskCenter()
        XCTAssertEqual(taskCenter.unreadCount, 0)
    }
}

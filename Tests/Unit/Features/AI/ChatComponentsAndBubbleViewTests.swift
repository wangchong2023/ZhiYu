//
//  ChatComponentsAndBubbleViewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 ChatMessage 消息气泡模型、角色区分与引用引用展开分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ChatComponentsAndBubbleViewTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ChatMessage 模型角色与创建

    func testChatMessage_UserAndAssistantRoles() {
        let userMsg = ChatMessage(role: .user, content: "你好，请解释 RAG 概念")
        let assistantMsg = ChatMessage(role: .assistant, content: "RAG 是检索增强生成")

        XCTAssertEqual(userMsg.role, .user)
        XCTAssertEqual(assistantMsg.role, .assistant)
        XCTAssertFalse(userMsg.content.isEmpty)
        XCTAssertFalse(assistantMsg.content.isEmpty)
    }

    // MARK: - 2. 消息引用实体与关联页面

    func testChatMessage_WithRelatedPages() {
        let pageID = UUID()
        let msgWithRef = ChatMessage(
            role: .assistant,
            content: "参考内容",
            relatedPageIDs: [pageID]
        )

        XCTAssertEqual(msgWithRef.relatedPageIDs.count, 1)
        XCTAssertEqual(msgWithRef.relatedPageIDs.first, pageID)
    }
}

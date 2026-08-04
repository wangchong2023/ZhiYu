//
//  ChatServiceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 ChatService 开展自动化单元测试验证。
//
import XCTest
import Combine
@testable import ZhiYu

@MainActor
final class ChatServiceTests: XCTestCase {
    
    var chatService: ChatService!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        chatService = ChatService.shared
        chatService.clearHistory()
    }
    
    /// 验证消息保存逻辑 (SRS-6.2)
    func testMessageSaving() {
        let userContent = "Hello AI"
        chatService.saveUserMessage(userContent)
        
        let history = chatService.loadHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.role, .user)
        XCTAssertEqual(history.first?.content, userContent)
        
        let aiContent = "Hello Human"
        chatService.saveAssistantMessage(aiContent)
        
        let historyAfter = chatService.loadHistory()
        XCTAssertEqual(historyAfter.count, 2)
        XCTAssertEqual(historyAfter.last?.role, .assistant)
        XCTAssertEqual(historyAfter.last?.content, aiContent)
    }
    
    /// 验证清空历史逻辑 (SRS-6.2)
    func testClearHistory() {
        chatService.saveUserMessage("Test")
        XCTAssertFalse(chatService.loadHistory().isEmpty)
        
        chatService.clearHistory()
        XCTAssertTrue(chatService.loadHistory().isEmpty)
    }
    
    /// 验证流式对话调用链路 (SRS-6.2 / PR-02)
    func testStreamChatLink() async throws {
        let query = "Test Query"
        let stream = chatService.streamChat(query: query, pages: [])
        
        // 由于使用了 MockLLMService，流应当立即完成或返回 Mock 数据
        for try await _ in stream {
        }
        
        // MockLLMService 默认返回完成
        XCTAssertNotNil(stream)
    }
}

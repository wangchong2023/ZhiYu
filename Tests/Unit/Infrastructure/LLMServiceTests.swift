//
//  LLMServiceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 LLMService 开展自动化单元测试验证。
//
import XCTest
import UFPCore
import Combine
@testable import ZhiYu

@MainActor
final class LLMServiceTests: XCTestCase {
    var service: LLMService!
    
    var mockChat: MockChatLLMService!
    var mockIngest: MockKnowledgeLLMService!
    var mockRerank: MockRetrievalLLMService!
    var mockConfig: LLMConfigManager!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        
        mockConfig = LLMConfigManager()
        ServiceContainer.shared.register(mockConfig, for: LLMConfigManager.self)
        
        mockChat = MockChatLLMService()
        ServiceContainer.shared.register(mockChat as any LLMChatServiceProtocol, for: (any LLMChatServiceProtocol).self)
        
        mockIngest = MockKnowledgeLLMService()
        ServiceContainer.shared.register(mockIngest as any LLMKnowledgeServiceProtocol, for: (any LLMKnowledgeServiceProtocol).self)
        
        mockRerank = MockRetrievalLLMService()
        ServiceContainer.shared.register(mockRerank as any LLMRetrievalServiceProtocol, for: (any LLMRetrievalServiceProtocol).self)
        
        // 实例化要测试的 Facade 门面
        service = LLMService()
    }
    
    override func tearDown() async throws {
        service = nil
        mockChat = nil
        mockIngest = nil
        mockRerank = nil
        mockConfig = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }
    
    // MARK: - 测试门面转发：Chat 模块
    
    func testChatFacadeForwardsCorrectly() async throws {
        let result = try await service.chat(query: "Hello", history: [], pages: [])
        
        XCTAssertEqual(mockChat.chatCallCount, 1, "LLMService 必须将 chat 请求转发给 LLMChatServiceProtocol")
        XCTAssertEqual(result.content, "Mock Chat Result")
    }
    
    func testGenerateFacadeForwardsCorrectly() async throws {
        let result = try await service.generate(prompt: "P", systemPrompt: "S")
        
        XCTAssertEqual(mockChat.generateCallCount, 1, "LLMService 必须将 generate 请求转发给 LLMChatServiceProtocol")
        XCTAssertEqual(result, "Mock Generated Result")
    }
    
    func testChatStreamFacadeForwardsCorrectly() async throws {
        let stream = service.chatStream(query: "Hi", history: [], pages: [])
        
        var combined = ""
        for try await chunk in stream {
            combined += chunk
        }
        
        XCTAssertEqual(mockChat.chatStreamCallCount, 1)
        XCTAssertEqual(combined, "Mock Stream Result")
    }
    
    // MARK: - 测试门面转发：Ingest 知识维护模块
    
    func testSmartIngestFacadeForwardsCorrectly() async throws {
        let result = try await service.smartIngest(title: "T", rawContent: "C", pages: [])
        
        XCTAssertEqual(mockIngest.smartIngestCallCount, 1, "LLMService 必须将 smartIngest 请求转发给 LLMKnowledgeServiceProtocol")
        XCTAssertEqual(result.title, "Mock Title")
    }
    
    func testDiscoverPotentialLinksFacadeForwardsCorrectly() async throws {
        let result = try await service.discoverPotentialLinks(content: "C", existingTitles: [])
        
        XCTAssertEqual(mockIngest.discoverCallCount, 1)
        XCTAssertEqual(result.count, 2)
    }
    
    func testAnalyzeForRefactoringFacadeForwardsCorrectly() async throws {
        let result = try await service.analyzeForRefactoring(pages: [])
        
        XCTAssertEqual(mockIngest.analyzeCallCount, 1)
        XCTAssertEqual(result.first?.type, "merge")
    }
    
    // MARK: - 测试门面转发：Retrieval 重排模块
    
    func testRerankFacadeForwardsCorrectly() async throws {
        let candidates = [KnowledgePage(title: "A", pageType: .entity, content: "A")]
        _ = try await service.rerank(query: "Q", candidates: candidates)
        
        XCTAssertEqual(mockRerank.rerankCallCount, 1, "LLMService 必须将 rerank 请求转发给 LLMRetrievalServiceProtocol")
    }
    
    func testExpandQueryFacadeForwardsCorrectly() async {
        let result = await service.expandQuery("Q")
        
        XCTAssertEqual(mockRerank.expandCallCount, 1)
        XCTAssertEqual(result.count, 2)
    }
    
    func testGenerateHypotheticalDocumentFacadeForwardsCorrectly() async {
        let result = await service.generateHypotheticalDocument(query: "Q")
        
        XCTAssertEqual(mockRerank.generateHypotheticalCallCount, 1)
        XCTAssertEqual(result, "Mock Hypothetical Document")
    }
}

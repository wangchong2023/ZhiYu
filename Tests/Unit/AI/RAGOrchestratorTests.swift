//
//  RAGOrchestratorTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 RAGOrchestrator 开展自动化单元测试验证。
//
import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class RAGOrchestratorTests: XCTestCase {
    @Dependency(\.taskCenter) var taskCenter

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        taskCenter.reset()
    }
    
    // MARK: - RAG Chat 同步编排测试
    
    /// 验证普通 RAG 对话 (Chat) 正常走完流程并返回结果
    func testRAGOrchestratorChatSuccess() async throws {
        let orchestrator = RAGOrchestrator()
        
        // 1. 设置 MockLLMService.generateHandler 产生定制回答
        // RAGOrchestrator.chat() 内部调用 llmService.generate()  
        guard let mockLLM = ServiceContainer.shared.resolve((any LLMServiceProtocol).self) as? MockLLMService else { XCTFail("MockLLMService 未注册"); return }
        mockLLM.generateHandler = { _, systemPrompt in
            XCTAssertTrue(systemPrompt.contains("量子力学"))
            return "量子力学是研究微观粒子的物理学分支。"
        }
        
        // 2. 构造输入数据
        let query = "什么是量子力学？"
        let page = KnowledgePage(title: "量子力学基础", content: "量子力学描述微观世界的物理定律。")
        
        // 3. 执行 Chat 编排
        let result = try await orchestrator.chat(query: query, history: [], pages: [page])
        
        // 4. 断言结果
        XCTAssertEqual(result.role, .assistant)
        XCTAssertEqual(result.content, "量子力学是研究微观粒子的物理学分支。")
        
        // 5. 验证 TaskCenter 任务是否成功完成
        let tasks = taskCenter.tasks
        XCTAssertFalse(tasks.isEmpty)
        if let lastTask = tasks.last {
            XCTAssertEqual(lastTask.name, "AI Chat")
            XCTAssertEqual(lastTask.target, query)
            switch lastTask.status {
            case .completed:
                break // 预期完成
            default:
                XCTFail("任务状态应该为 completed，但实际是 \(lastTask.status)")
            }
        }
    }
    
    // MARK: - RAG ChatStream 流式编排测试
    
    /// 验证 RAG 流式对话 (ChatStream) 正常分块拼接返回并完成任务
    func testRAGOrchestratorChatStreamSuccess() async throws {
        let orchestrator = RAGOrchestrator()
        
        // 1. 设置 MockLLMService.chatStreamHandler 产生流式 Chunk
        // RAGOrchestrator.chatStream() 内部调用 llmService.chatStream()
        guard let mockLLM = ServiceContainer.shared.resolve((any LLMServiceProtocol).self) as? MockLLMService else { XCTFail("MockLLMService 未注册"); return }
        mockLLM.chatStreamHandler = { _, _, _ in
            return AsyncThrowingStream { continuation in
                continuation.yield("量子")
                continuation.yield("力学")
                continuation.yield("是微观")
                continuation.yield("物理学")
                continuation.finish()
            }
        }
        
        // 2. 构造输入数据
        let query = "什么是量子力学流？"
        let page = KnowledgePage(title: "量子力学基础", content: "量子力学描述微观世界的物理定律。")
        
        // 3. 消费 AsyncThrowingStream 流
        let stream = orchestrator.chatStream(query: query, history: [], pages: [page])
        var gatheredResponse = ""
        for try await chunk in stream {
            gatheredResponse += chunk
        }
        
        // 4. 断言拼接结果
        XCTAssertEqual(gatheredResponse, "量子力学是微观物理学")
        
        // 5. 验证 TaskCenter 中的任务是否成功注册并完成
        let tasks = taskCenter.tasks
        XCTAssertFalse(tasks.isEmpty)
        if let streamTask = tasks.first(where: { $0.name == "AI Chat Stream" }) {
            XCTAssertEqual(streamTask.target, query)
            switch streamTask.status {
            case .completed:
                break // 预期完成
            default:
                XCTFail("流式任务状态应该为 completed，但实际是 \(streamTask.status)")
            }
        }
    }
    
    /// 验证当大模型流式调用出错时，任务能够正常标记为失败并抛出异常
    func testRAGOrchestratorChatStreamFailure() async throws {
        let orchestrator = RAGOrchestrator()
        
        // 1. 设置 MockLLMService.chatStreamHandler 流式抛出异常
        // RAGOrchestrator.chatStream() 内部调用 llmService.chatStream()
        guard let mockLLM = ServiceContainer.shared.resolve((any LLMServiceProtocol).self) as? MockLLMService else { XCTFail("MockLLMService 未注册"); return }
        struct MockError: Error, LocalizedError {
            var errorDescription: String? { "Mock LLM Timeout Error" }
        }
        
        mockLLM.chatStreamHandler = { _, _, _ in
            return AsyncThrowingStream { continuation in
                continuation.yield("初步内容")
                continuation.finish(throwing: MockError())
            }
        }
        
        // 2. 消费流并验证异常捕获
        let query = "触发流失败测试"
        let page = KnowledgePage(title: "测试页面", content: "内容")
        let stream = orchestrator.chatStream(query: query, history: [], pages: [page])
        
        do {
            var gathered = ""
            for try await chunk in stream {
                gathered += chunk
            }
            XCTFail("流式请求应该抛出异常，但却成功返回了: \(gathered)")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Mock LLM Timeout Error")
        }
        
        // 3. 验证 TaskCenter 任务是否标记为失败
        let tasks = taskCenter.tasks
        if let failedTask = tasks.first(where: { $0.name == "AI Chat Stream" && $0.target == query }) {
            switch failedTask.status {
            case .failed(let reason):
                XCTAssertEqual(reason, "Mock LLM Timeout Error")
            default:
                XCTFail("任务应该为 failed，当前是 \(failedTask.status)")
            }
        } else {
            XCTFail("未能在 TaskCenter 找到对应的流式失败任务")
        }
    }
}

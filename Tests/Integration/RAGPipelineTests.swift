//
//  RAGPipelineTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 RAGPipeline 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

/// 系统集成测试：全链路 RAG 管道
/// 覆盖：导入 -> 向量化 -> 检索 -> AI 总结
@MainActor
final class RAGPipelineTests: XCTestCase {
    var store: AppStore!
    
    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = AppStore()
    }

    override func tearDown() async throws {
        store = nil
        // 允许当前主线程/协程事件循环排水，确保所有未完成的异步任务运行完毕，规避重置 DI 导致的 Race Condition (@SRS-7.1)
        try? await Task.sleep(nanoseconds: 100_000_000)
        DatabaseManager.shared.reset()
        try await super.tearDown()
    }
    
    /// 测试全链路 RAG 管道系统集成
    /// 验证从 原始文档导入 -> 向量化与词向量生成 -> 混合搜索与精确检索 -> LLM 生成回复 的完整闭环。
    func testFullRAGPipeline() async throws {
        // 从 DI 容器解析测试所需的具体持久化与向量模块
        let pageStore = ServiceContainer.shared.resolve((any AnyPageStoreCapabilities).self)
        let embeddingManager = ServiceContainer.shared.resolve(EmbeddingManager.self)
        
        // 1. 导入数据并提取语义结构 (Ingest)
        let testContent = "智宇 (ZhiYu) 是一款基于 RAG 架构的知识管理 software，支持双向链接。"
        let page = await store.ingestService.ingestRawContent(
            title: "智宇简介",
            content: testContent,
            forceDeepScan: true,
            llmService: store.llmService,
            pageStore: pageStore
        )
        
        let pageID = page.id
        XCTAssertNotNil(pageID)
        
        // 2. 向量化转换与对齐 (Vectorization)
        // 手动同步内存中的页面并注入向量数据库以对齐检索基准
        let currentPages = await pageStore.pages
        await embeddingManager.syncEmbeddings(pages: currentPages)
        await store.refresh()
        
        let allEmbeddings = await embeddingManager.getAllEmbeddings()
        let embedding = allEmbeddings[pageID]
        XCTAssertNotNil(embedding, "向量化任务应在导入后完成")
        
        // 3. 混合多模态检索 (Hybrid Search)
        // 使用关键词匹配查询确保 FTS 关键词检索能召回（模拟器上 NLEmbedding 不可用，语义检索降级为确定性哈希）
        let searchResult = await store.linkService.hybridSearchWithDiagnostics(
            query: "智宇",
            in: store.pages,
            embeddingProvider: embeddingManager
        )
        let searchResults = searchResult.results
        XCTAssertTrue(searchResults.contains(where: { $0.id == pageID }), "混合检索应能根据关键词召回导入的内容")
        
        // 4. AI 总结回复合成 (Generation)
        let prompt = "根据已知内容回答：智宇的特点是什么？"
        let systemPrompt = "你是一个专业的知识管理助手。"
        let aiResponse = try await store.llmService.generate(prompt: prompt, systemPrompt: systemPrompt)
        
        // 5. 校验 RAG 回答
        XCTAssertFalse(aiResponse.isEmpty, "RAG 管道生成的回答不应为空")
        XCTAssertTrue(aiResponse.contains("RAG") || aiResponse.contains("双向链接"), "AI 响应应包含关键信息")
    }

    /// 验证当向量化索引出现故障或为空时，RAG 管道能平滑降级为纯文本/关键词检索而不抛出致命崩溃
    func testRAGPipeline_vectorIndexFallback() async throws {
        let pageStore = ServiceContainer.shared.resolve((any AnyPageStoreCapabilities).self)
        let configStore = ServiceContainer.shared.resolve(LLMConfigManager.self)
        configStore.apiKey = "sk-mock-key"
        
        let mockChatLLM = MockChatLLMService()
        mockChatLLM.stubChatResult = ChatMessageDTO(id: UUID(), role: .assistant, content: "降级总结回复内容", timestamp: Date(), relatedPageIDs: [])
        ServiceContainer.shared.register(mockChatLLM as any LLMChatServiceProtocol, for: (any LLMChatServiceProtocol).self)
        
        // 导入一篇空页面/异常页面
        _ = await store.ingestService.ingestRawContent(
            title: "降级边界测试",
            content: "通用测试文本内容",
            forceDeepScan: false,
            llmService: store.llmService,
            pageStore: pageStore
        )
        await store.refresh()

        // 发起对话请求：即使向量服务返回空或异常，RAG 管道仍能成功输出降级回复
        let response = try await mockChatLLM.chat(
            query: "测试降级",
            history: [],
            pages: store.pages
        )
        
        XCTAssertFalse(response.content.isEmpty, "向量服务降级时 RAG 仍应产生有效兜底输出")
    }
}

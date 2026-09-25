//
//  NoOpLLMServicesSupplementTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 LLM 相关 NoOp 服务（Chat/Knowledge/Retrieval/LLMService）
//           返回安全默认值（空/false/nil/throw），不崩溃。
//

import XCTest
import UFPCore
@testable import ZhiYu

/// LLM 相关 NoOp 服务补盲测试
@MainActor
final class NoOpLLMServicesSupplementTests: XCTestCase {

    // MARK: - NoOpLLMChatService

    /// NoOpLLMChatService 应返回安全默认值
    func testNoOpLLMChatServiceReturnsSafeDefaults() async throws {
        let service = NoOpLLMChatService()
        XCTAssertFalse(service.isEnabled, "NoOp isEnabled 应为 false")
        let chat = try await service.chat(query: "test", history: [], pages: [])
        XCTAssertEqual(chat.content, "", "NoOp chat 应返回空内容")
        let generated = try await service.generate(prompt: "test", systemPrompt: "test", maxTokens: 100)
        XCTAssertEqual(generated, "", "NoOp generate 应返回空字符串")
    }

    /// NoOpLLMChatService chatStream 应立即 finish
    func testNoOpLLMChatServiceChatStreamFinishesImmediately() async throws {
        let service = NoOpLLMChatService()
        let stream = service.chatStream(query: "test", history: [], pages: [])
        var count = 0
        for try await _ in stream {
            count += 1
        }
        XCTAssertEqual(count, 0, "NoOp chatStream 应不产生任何 chunk")
    }

    // MARK: - NoOpLLMKnowledgeService

    /// NoOpLLMKnowledgeService smartIngest 应保留 title 返回空内容
    func testNoOpLLMKnowledgeServiceSmartIngestKeepsTitle() async throws {
        let service = await NoOpLLMKnowledgeService()
        let result = try await service.smartIngest(title: "test", rawContent: "content", pages: [])
        XCTAssertEqual(result.title, "test", "NoOp smartIngest 应保留 title")
        XCTAssertEqual(result.compiledContent, "", "NoOp smartIngest 应返回空内容")
        XCTAssertTrue(result.suggestedTags.isEmpty, "NoOp smartIngest 应返回空标签")
    }

    /// NoOpLLMKnowledgeService discoverPotentialLinks 应返回空数组
    func testNoOpLLMKnowledgeServiceDiscoverPotentialLinksReturnsEmptyArray() async throws {
        let service = await NoOpLLMKnowledgeService()
        let links = try await service.discoverPotentialLinks(content: "test", existingTitles: [])
        XCTAssertTrue(links.isEmpty, "NoOp discoverPotentialLinks 应返回空数组")
    }

    /// NoOpLLMKnowledgeService foldContent 应返回 existingContent
    func testNoOpLLMKnowledgeServiceFoldContentReturnsExistingContent() async throws {
        let service = await NoOpLLMKnowledgeService()
        let folded = try await service.foldContent(existingContent: "old", newContent: "new", title: "test")
        XCTAssertEqual(folded, "old", "NoOp foldContent 应返回 existingContent")
    }

    /// NoOpLLMKnowledgeService analyzeForRefactoring 应返回空数组
    func testNoOpLLMKnowledgeServiceAnalyzeForRefactoringReturnsEmptyArray() async throws {
        let service = await NoOpLLMKnowledgeService()
        let suggestions = try await service.analyzeForRefactoring(pages: [])
        XCTAssertTrue(suggestions.isEmpty, "NoOp analyzeForRefactoring 应返回空数组")
    }

    // MARK: - NoOpLLMRetrievalService

    /// NoOpLLMRetrievalService rewriteQuery 应返回原 query
    func testNoOpLLMRetrievalServiceRewriteQueryReturnsOriginalQuery() async {
        let service = await NoOpLLMRetrievalService()
        let rewritten = await service.rewriteQuery("test")
        XCTAssertEqual(rewritten, "test", "NoOp rewriteQuery 应返回原 query")
    }

    /// NoOpLLMRetrievalService expandQuery 应返回空数组
    func testNoOpLLMRetrievalServiceExpandQueryReturnsEmptyArray() async {
        let service = await NoOpLLMRetrievalService()
        let expanded = await service.expandQuery("test")
        XCTAssertTrue(expanded.isEmpty, "NoOp expandQuery 应返回空数组")
    }

    /// NoOpLLMRetrievalService rerank 应原样返回 candidates
    func testNoOpLLMRetrievalServiceRerankReturnsCandidatesAsIs() async throws {
        let service = await NoOpLLMRetrievalService()
        let reranked = try await service.rerank(query: "test", candidates: [])
        XCTAssertTrue(reranked.isEmpty, "NoOp rerank 空输入应返回空数组")
    }
    /// NoOpLLMRetrievalService generateHypotheticalDocument 应返回空字符串
    func testNoOpLLMRetrievalServiceGenerateHypotheticalDocumentReturnsEmptyString() async {
        let service = await NoOpLLMRetrievalService()
        let hyde = await service.generateHypotheticalDocument(query: "test")
        XCTAssertEqual(hyde, "", "NoOp generateHypotheticalDocument 应返回空字符串")
    }

    // MARK: - NoOpLLMService

    /// NoOpLLMService 应返回安全默认值
    func testNoOpLLMServiceReturnsSafeDefaults() async throws {
        let service = await NoOpLLMService()
        XCTAssertFalse(service.isEnabled, "NoOp isEnabled 应为 false")
        XCTAssertEqual(service.apiKey, "", "NoOp apiKey 应为空")
        XCTAssertEqual(service.baseURL, "", "NoOp baseURL 应为空")
        XCTAssertEqual(service.model, "", "NoOp model 应为空")
        XCTAssertFalse(service.autoScan, "NoOp autoScan 应为 false")
        XCTAssertFalse(service.autoRefactor, "NoOp autoRefactor 应为 false")
    }

    /// NoOpLLMService chat 应返回空内容
    func testNoOpLLMServiceChatReturnsEmptyContent() async throws {
        let service = await NoOpLLMService()
        let chat = try await service.chat(query: "test", history: [], pages: [])
        XCTAssertEqual(chat.content, "", "NoOpLLMService chat 应返回空内容")
    }

    /// NoOpLLMService chatStream 应立即 finish
    func testNoOpLLMServiceChatStreamFinishesImmediately() async throws {
        let service = await NoOpLLMService()
        let stream = service.chatStream(query: "test", history: [], pages: [])
        var count = 0
        for try await _ in stream {
            count += 1
        }
        XCTAssertEqual(count, 0, "NoOpLLMService chatStream 应不产生任何 chunk")
    }

    /// NoOpLLMService smartIngest 应保留 title
    func testNoOpLLMServiceSmartIngestKeepsTitle() async throws {
        let service = await NoOpLLMService()
        let result = try await service.smartIngest(title: "test", rawContent: "content", pages: [])
        XCTAssertEqual(result.title, "test")
    }

    /// NoOpLLMService rewriteQuery 应返回原 query
    func testNoOpLLMServiceRewriteQueryReturnsOriginalQuery() async {
        let service = await NoOpLLMService()
        let rewritten = await service.rewriteQuery("test")
        XCTAssertEqual(rewritten, "test")
    }
}

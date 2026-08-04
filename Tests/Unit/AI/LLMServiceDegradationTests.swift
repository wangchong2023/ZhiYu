//
//  LLMServiceDegradationTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 LLMService 门面在子服务未注册或不可用时的降级返回语义。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class LLMServiceDegradationTests: XCTestCase {

    private var config: LLMConfigManager!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        config = LLMConfigManager()
        ServiceContainer.shared.register(config, for: LLMConfigManager.self)
    }

    override func tearDown() async throws {
        config = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - Chat 子服务未注册

    func testGenerateThrowsNotConfiguredWhenChatServiceMissing() async {
        let service = LLMService()
        do {
            _ = try await service.generate(prompt: "P", systemPrompt: "S")
            XCTFail("未注册 ChatService 时 generate 应抛出 notConfigured")
        } catch LLMError.notConfigured {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.notConfigured，实际：\(error)")
        }
    }

    func testChatThrowsNotConfiguredWhenChatServiceMissing() async {
        let service = LLMService()
        do {
            _ = try await service.chat(query: "Q", history: [], pages: [])
            XCTFail("未注册 ChatService 时 chat 应抛出 notConfigured")
        } catch LLMError.notConfigured {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.notConfigured，实际：\(error)")
        }
    }

    func testChatStreamFinishesWithErrorWhenChatServiceMissing() async {
        let service = LLMService()
        let stream = service.chatStream(query: "Q", history: [], pages: [])
        do {
            for try await _ in stream { }
            XCTFail("未注册 ChatService 时 chatStream 应以错误结束")
        } catch LLMError.notConfigured {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.notConfigured，实际：\(error)")
        }
    }

    // MARK: - Ingest 子服务未注册：降级返回

    func testSmartIngestThrowsNotConfiguredWhenIngestMissing() async {
        let service = LLMService()
        do {
            _ = try await service.smartIngest(title: "T", rawContent: "C", pages: [])
            XCTFail("未注册 IngestService 时 smartIngest 应抛出 notConfigured")
        } catch LLMError.notConfigured {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.notConfigured，实际：\(error)")
        }
    }

    func testDiscoverPotentialLinksReturnsEmptyWhenIngestMissing() async {
        let service = LLMService()
        let result = try? await service.discoverPotentialLinks(content: "C", existingTitles: [])
        XCTAssertEqual(result, [], "未注册 IngestService 时 discoverPotentialLinks 应降级返回空数组")
    }

    func testFoldContentReturnsConcatenationWhenIngestMissing() async throws {
        let service = LLMService()
        let result = try await service.foldContent(existingContent: "A", newContent: "B", title: "T")
        XCTAssertEqual(result, "A\nB", "未注册 IngestService 时 foldContent 应降级返回 existing + newline + new")
    }

    func testAnalyzeForRefactoringReturnsEmptyWhenIngestMissing() async {
        let service = LLMService()
        let result = try? await service.analyzeForRefactoring(pages: [])
        XCTAssertEqual(result?.count ?? 0, 0, "未注册 IngestService 时 analyzeForRefactoring 应降级返回空数组")
    }

    // MARK: - Retrieval 子服务未注册：降级返回

    func testRewriteQueryReturnsOriginalWhenRerankerMissing() async {
        let service = LLMService()
        let result = await service.rewriteQuery("原始查询")
        XCTAssertEqual(result, "原始查询", "未注册 Reranker 时 rewriteQuery 应降级返回原始查询")
    }

    func testExpandQueryReturnsSingleElementWhenRerankerMissing() async {
        let service = LLMService()
        let result = await service.expandQuery("查询")
        XCTAssertEqual(result, ["查询"], "未注册 Reranker 时 expandQuery 应降级返回仅含原始查询的单元素数组")
    }

    func testRerankReturnsOriginalCandidatesWhenRerankerMissing() async throws {
        let service = LLMService()
        let candidates: [any KnowledgePageRepresentable] = [
            KnowledgePage(title: "A", pageType: .entity, content: "A")
        ]
        let result = try await service.rerank(query: "Q", candidates: candidates)
        XCTAssertEqual(result.count, 1, "未注册 Reranker 时 rerank 应降级返回原始候选集")
    }

    func testRerankChunksReturnsOriginalWhenRerankerMissing() async {
        let service = LLMService()
        let chunks = [PageChunk(id: "test_0", pageID: UUID(), chunkType: "text", content: "chunk", anchorPath: nil, index: 0)]
        let result = await service.rerankChunks(query: "Q", chunks: chunks)
        XCTAssertEqual(result.count, 1, "未注册 Reranker 时 rerankChunks 应降级返回原始 chunks")
    }

    func testGenerateHypotheticalDocumentReturnsQueryWhenRerankerMissing() async {
        let service = LLMService()
        let result = await service.generateHypotheticalDocument(query: "查询")
        XCTAssertEqual(result, "查询", "未注册 Reranker 时 generateHypotheticalDocument 应降级返回原始查询")
    }
}

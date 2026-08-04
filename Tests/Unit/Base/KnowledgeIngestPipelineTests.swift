import XCTest
@testable import ZhiYu

/// KnowledgeIngestPipeline 集成测试（通过 process() 公共接口验证管道流程）
@MainActor
final class KnowledgeIngestPipelineTests: XCTestCase {

    private let pipeline = KnowledgeIngestPipeline.shared
    private var mockEmbedding: MockEmbeddingProvider!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        mockEmbedding = MockEmbeddingProvider()
    }

    override func tearDown() async throws {
        mockEmbedding = nil
        try await super.tearDown()
    }

    // MARK: - process 管道流程测试

    func testProcess_withoutLLM_returnsOriginalContent() async throws {
        let content = "这是一段测试用的纯文本内容。"
        let pageID = UUID()

        let result = try await pipeline.process(
            content: content,
            pageID: pageID,
            llm: nil,
            embeddingProvider: mockEmbedding
        )

        XCTAssertEqual(result, content)
    }

    func testProcess_withoutLLM_indexChunksNotCalled() async throws {
        let content = "不需要 LLM 的简单内容。"
        let pageID = UUID()
        _ = try await pipeline.process(
            content: content,
            pageID: pageID,
            llm: nil,
            embeddingProvider: mockEmbedding
        )

        XCTAssertTrue(mockEmbedding.indexChunksCalled)
    }

    func testProcess_withLLM_emptyContent() async throws {
        let content = ""
        let pageID = UUID()
        let mockLLM = TestMocks.createMockLLMService()

        let result = try await pipeline.process(
            content: content,
            pageID: pageID,
            llm: mockLLM,
            embeddingProvider: mockEmbedding
        )

        XCTAssertEqual(result, "")
    }

    func testProcess_withLLM_shortContent() async throws {
        let content = "简短内容。"
        let pageID = UUID()
        let mockLLM = TestMocks.createMockLLMService()

        let result = try await pipeline.process(
            content: content,
            pageID: pageID,
            llm: mockLLM,
            embeddingProvider: mockEmbedding
        )

        XCTAssertEqual(result, content)
    }

    func testProcess_withLLM_longerContent_containsContent() async throws {
        let content = """
        # 测试标题

        这是一段较长的测试内容，用于验证管道能够正确处理并返回原始内容。
        第二段内容。
        """
        let pageID = UUID()
        let mockLLM = TestMocks.createMockLLMService()

        let result = try await pipeline.process(
            content: content,
            pageID: pageID,
            llm: mockLLM,
            embeddingProvider: mockEmbedding
        )

        XCTAssertTrue(result.contains("测试标题"))
        XCTAssertTrue(result.contains("一段较长的测试内容"))
    }

    func testProcess_withTableMarkdown_keepsTableContent() async throws {
        let content = "| A | B |\n| --- | --- |\n| 1 | 2 |"
        let pageID = UUID()
        let mockLLM = TestMocks.createMockLLMService()

        let result = try await pipeline.process(
            content: content,
            pageID: pageID,
            llm: mockLLM,
            embeddingProvider: mockEmbedding
        )

        XCTAssertTrue(result.contains("| A | B |"))
    }

    func testProcess_multipleCalls_noSideEffects() async throws {
        let content = "独立调用测试。"
        let mockLLM = TestMocks.createMockLLMService()

        let r1 = try await pipeline.process(
            content: content,
            pageID: UUID(),
            llm: nil,
            embeddingProvider: mockEmbedding
        )

        let r2 = try await pipeline.process(
            content: content,
            pageID: UUID(),
            llm: mockLLM,
            embeddingProvider: mockEmbedding
        )

        XCTAssertEqual(r1, content)
        XCTAssertEqual(r2, content)
    }

    func testProcess_indexChunksCalledWithExpectedPageID() async throws {
        let content = "追踪 pageID 内容。"
        let pageID = UUID()

        _ = try await pipeline.process(
            content: content,
            pageID: pageID,
            llm: nil,
            embeddingProvider: mockEmbedding
        )

        XCTAssertEqual(mockEmbedding.lastIndexedPageID, pageID)
    }
}

// MARK: - Mock EmbeddingProvider

private final class MockEmbeddingProvider: EmbeddingProvider {
    nonisolated(unsafe) var indexChunksCalled = false
    nonisolated(unsafe) var lastIndexedPageID: UUID?

    func getAllEmbeddings() async -> [UUID: [Float]] { [:] }
    func syncEmbeddings(pages: [KnowledgePage]) async {}
    func updateEmbedding(for page: KnowledgePage) async {}
    func indexChunks(pageID: UUID, chunks: [PageChunk]) async {
        indexChunksCalled = true
        lastIndexedPageID = pageID
    }
    
    func vectorizeChunks(chunks: [String]) async -> [[Float]] { [] }
    func search(query: String, topK: Int) async -> [(id: UUID, score: Float)] { [] }
    func multiQuerySearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func hydeSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func selfReflectionSearch(query: String, candidates: [(chunk: PageChunk, score: Float)]) async -> [(chunk: PageChunk, score: Float)] { [] }
    func advancedSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func loadInitialCache() async {}
    func clearCacheAndReload() async {}
}

// MARK: - TestMocks convenience

private enum TestMocks {
    @MainActor
    static func createMockLLMService() -> MockLLMService {
        let mock = MockLLMService()
        return mock
    }
}

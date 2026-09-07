//
//  AIWorkflowTestMocks.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AIWorkflowStore 深度测试共享 Mock 与 Equatable 扩展 — 提供可控 LLM Mock、
//            内存版 KnowledgeRepository/VectorIndexableStore/EmbeddingProvider Mock，
//            以及测试专用 Equatable 一致性实现，供 AIWorkflowState/Suggestions/LintHealth/ClearAll
//            四个深度测试文件共享使用。
//  拆分来源：AIWorkflowStoreDeepTests.swift（按 MARK 分段拆分，本文件为共享 Mock 基础设施）。
//

import XCTest
import UFPCore
import Combine
import Dependencies
@testable import ZhiYu

// MARK: - 测试专用 Equatable 一致性（仅测试 target 内生效，避免修改生产模型文件）

extension RefactorSuggestionDTO: Equatable {
    public static func == (lhs: RefactorSuggestionDTO, rhs: RefactorSuggestionDTO) -> Bool {
        lhs.type == rhs.type && lhs.target == rhs.target && lhs.reason == rhs.reason && lhs.suggestion == rhs.suggestion
    }
}

extension PotentialLinkSuggestion: Equatable {
    public static func == (lhs: PotentialLinkSuggestion, rhs: PotentialLinkSuggestion) -> Bool {
        lhs.id == rhs.id && lhs.sourcePageID == rhs.sourcePageID && lhs.sourceTitle == rhs.sourceTitle && lhs.targetTitle == rhs.targetTitle
    }
}

extension LintIssue: Equatable {
    public static func == (lhs: LintIssue, rhs: LintIssue) -> Bool {
        lhs.id == rhs.id && lhs.severity == rhs.severity && lhs.type == rhs.type && lhs.pageID == rhs.pageID && lhs.message == rhs.message && lhs.suggestion == rhs.suggestion
    }
}

extension QuizModel: Equatable {
    public static func == (lhs: QuizModel, rhs: QuizModel) -> Bool {
        lhs.title == rhs.title && lhs.questions.count == rhs.questions.count
    }
}

// MARK: - 可控 LLM Mock（继承 LLMService，支持 @Inject 解析 + 按方法返回不同结果/抛错/记录调用）

/// 可控 LLM 服务 Mock：继承 LLMService 以兼容 @Inject(llmService: any LLMServiceProtocol) 解析，
/// 同时记录 discoverPotentialLinks / analyzeForRefactoring / generate 调用，支持按调用返回不同响应或抛错。
@MainActor
final class AIWorkflowControllableLLM: LLMService, @unchecked Sendable {
    override var isEnabled: Bool { get { isEnabledStub } set { isEnabledStub = newValue } }
    var isEnabledStub = true

    /// discoverPotentialLinks 返回的标题列表
    var stubDiscoverLinks: [String] = []
    /// discoverPotentialLinks 抛出的错误（优先于 stubDiscoverLinks）
    var stubDiscoverError: Error?
    /// analyzeForRefactoring 返回的建议列表
    var stubRefactorSuggestions: [RefactorSuggestionDTO] = []
    /// analyzeForRefactoring 抛出的错误（优先于 stubRefactorSuggestions）
    var stubRefactorError: Error?
    /// generate 返回的固定文本
    var stubGenerateResult: String = "AI 生成结果"
    /// generate 抛出的错误（优先于 stubGenerateResult）
    var stubGenerateError: Error?

    /// 记录所有 discoverPotentialLinks 调用的 (content, existingTitles)
    private(set) var discoverCalls: [(content: String, existingTitles: [String])] = []
    /// 记录所有 analyzeForRefactoring 调用的 pages 数量
    private(set) var refactorCalls: [Int] = []
    /// 记录所有 generate 调用的 (prompt, systemPrompt)
    private(set) var generateCalls: [(prompt: String, systemPrompt: String)] = []

    override func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        ChatMessageDTO(role: .assistant, content: stubGenerateResult)
    }

    override func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    override func generate(prompt: String, systemPrompt: String, maxTokens: Int = PromptConstants.TokenLimits.defaultMaxOutputTokens) async throws -> String {
        generateCalls.append((prompt, systemPrompt))
        if let error = stubGenerateError { throw error }
        return stubGenerateResult
    }

    override func smartIngest(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) async throws -> SmartIngestResultDTO {
        SmartIngestResultDTO(title: title, compiledContent: "", suggestedTags: [], suggestedType: "", relatedTitles: [], summary: "")
    }

    override func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] {
        discoverCalls.append((content, existingTitles))
        if let error = stubDiscoverError { throw error }
        return stubDiscoverLinks
    }

    override func foldContent(existingContent: String, newContent: String, title: String) async throws -> String { "" }

    override func analyzeForRefactoring(pages: [any KnowledgePageRepresentable]) async throws -> [RefactorSuggestionDTO] {
        refactorCalls.append(pages.count)
        if let error = stubRefactorError { throw error }
        return stubRefactorSuggestions
    }

    override func rewriteQuery(_ query: String) async -> String { query }
    override func expandQuery(_ query: String) async -> [String] { [query] }
    override func rerank(query: String, candidates: [any KnowledgePageRepresentable]) async throws -> [any KnowledgePageRepresentable] { candidates }
    override func rerankChunks(query: String, chunks: [PageChunk]) async -> [PageChunk] { chunks }
    override func generateHypotheticalDocument(query: String) async -> String { query }
}

// MARK: - 内存版 KnowledgeRepository Mock（避免触碰真实数据库，支持自定义返回页面列表）

/// 内存版知识库仓储 Mock，用于 runLint/runAIScan/fetchFixSuggestion/findSimilarPages 的页面数据注入。
final class AIWorkflowMockKnowledgeRepository: KnowledgeRepository, @unchecked Sendable {
    /// fetchAll 返回的页面列表
    var stubPages: [KnowledgePage] = []
    /// fetchAll 抛出的错误（优先于 stubPages）
    var stubFetchAllError: Error?

    func fetchAll() async throws -> [KnowledgePage] {
        if let error = stubFetchAllError { throw error }
        return stubPages
    }

    func fetch(id: UUID) async throws -> KnowledgePage? { stubPages.first { $0.id == id } }
    func save(_ page: KnowledgePage) async throws {}
    func delete(id: UUID) async throws {}
    func search(query: String) async throws -> [KnowledgePage] { [] }
    func fetchBacklinks(for id: UUID) async throws -> [UUID] { [] }
    func renameTag(old: String, to new: String) async throws {}
    func deleteTag(_ tag: String) async throws {}
    func count() async throws -> Int { stubPages.count }
}

// MARK: - 内存版 VectorIndexableStore Mock（支持 findSimilarPages 自定义返回结果）

/// 内存版向量存储 Mock，用于 findSimilarPages 的语义检索结果注入。
final class AIWorkflowMockVectorStore: VectorIndexableStore, @unchecked Sendable {
    let embeddingProvider: any EmbeddingProvider
    init(embeddingProvider: any EmbeddingProvider) {
        self.embeddingProvider = embeddingProvider
    }
}

/// 内存版 EmbeddingProvider Mock，支持自定义 search 返回的 (id, score) 列表。
final class AIWorkflowMockEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    /// search 返回的 (id, score) 列表
    var stubSearchResults: [(id: UUID, score: Float)] = []

    func getAllEmbeddings() async -> [UUID: [Float]] { [:] }
    func syncEmbeddings(pages: [KnowledgePage]) async {}
    func updateEmbedding(for page: KnowledgePage) async {}
    func indexChunks(pageID: UUID, chunks: [PageChunk]) async {}
    func vectorizeChunks(chunks: [String]) async -> [[Float]] { [] }
    func search(query: String, topK: Int) async -> [(id: UUID, score: Float)] {
        Array(stubSearchResults.prefix(topK))
    }
    func multiQuerySearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func hydeSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func selfReflectionSearch(query: String, candidates: [(chunk: PageChunk, score: Float)]) async -> [(chunk: PageChunk, score: Float)] { [] }
    func advancedSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func loadInitialCache() async {}
    func clearCacheAndReload() async {}
}

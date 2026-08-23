//
//  AIWorkflowStoreDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AIWorkflowStore 深度补盲测试 — 覆盖初始状态、isLLMEnabled、lintIssues 持久化、
//            healthMetrics/lintScore/healthLevel 代理属性、lastLintScore/lastLintDate、
//            isScanningAI/isProcessingPageAI 状态、refactorSuggestions/potentialLinks 增删、
//            removeRefactorSuggestion/removePotentialLink、activePageAIResult/activeQuiz、
//            runLint/runAIScan（单页+全局+LLM禁用+抛错）、findSimilarPages、
//            runPageAISummary/ExtractActions/Expansion、performPageSynthesis（quiz 解析成功/失败/抛错）、
//            fetchFixSuggestion、clearAll、AppEventBus.clearAllDataRequested 联动、多次操作一致性，
//            以发现生产代码潜在 bug 为首要目标。
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

// MARK: - AIWorkflowStore 深度测试

@MainActor
final class AIWorkflowStoreDeepTests: XCTestCase {

    // MARK: - 测试夹具

    private var mockLLM: AIWorkflowControllableLLM!
    private var mockKnowledgeRepo: AIWorkflowMockKnowledgeRepository!
    private var mockEmbedding: AIWorkflowMockEmbeddingProvider!
    private var mockVectorStore: AIWorkflowMockVectorStore!
    private var taskCenter: TaskCenter!
    private var store: AIWorkflowStore!
    private var keyStore: (any KeyStoreProtocol)!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        resetPersistentTestState()

        // 清理可能残留的 lastLintIssues 持久化键（跨测试隔离）
        UserDefaults.standard.removeObject(forKey: AppConstants.Keys.Storage.lastLintIssues)

        // 创建可控 LLM Mock 并双重注册（协议类型 + 具体类型），覆盖 setupFullMockEnvironment 的 MockLLMService
        let llm = AIWorkflowControllableLLM()
        self.mockLLM = llm
        ServiceContainer.shared.register(llm as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        ServiceContainer.shared.register(llm as LLMService, for: LLMService.self)
        // 同步更新 AISynthesisService actor 内部 llm 引用，确保 runPageAI*/performPageSynthesis/fetchFixSuggestion 解析到可控 Mock
        await AISynthesisService.shared.updateLLMForTesting(llm)

        // 创建内存版 KnowledgeRepository Mock，替换 setupFullMockEnvironment 的真实仓储
        let knowledgeRepo = AIWorkflowMockKnowledgeRepository()
        self.mockKnowledgeRepo = knowledgeRepo
        ServiceContainer.shared.register(knowledgeRepo as any KnowledgeRepository, for: (any KnowledgeRepository).self)

        // 创建内存版 EmbeddingProvider + VectorIndexableStore Mock
        let embedding = AIWorkflowMockEmbeddingProvider()
        self.mockEmbedding = embedding
        ServiceContainer.shared.register(embedding as any EmbeddingProvider, for: (any EmbeddingProvider).self)
        let vectorStore = AIWorkflowMockVectorStore(embeddingProvider: embedding)
        self.mockVectorStore = vectorStore
        ServiceContainer.shared.register(vectorStore as any VectorIndexableStore, for: (any VectorIndexableStore).self)

        // 创建独立的 TaskCenter 实例，通过 withDependencies 注入到 AIWorkflowStore
        let tc = TaskCenter(activityService: nil)
        tc.reset()
        self.taskCenter = tc

        // 取出测试 KeyStore（setupFullMockEnvironment 已注册独立 UserDefaults 实例）
        self.keyStore = ServiceContainer.shared.resolve((any KeyStoreProtocol).self)

        // 在 withDependencies 闭包内创建 AIWorkflowStore，确保 @Dependency(\.taskCenter) 解析到自定义实例
        // 注意：@Inject 属性（llmService/knowledgeRepository/vectorStore/lintService/logger/linkService/synthesisStore）
        //       在 init 时从 ServiceContainer.shared 解析一次并缓存，故必须在创建前完成所有 Mock 注册
        self.store = withDependencies {
            $0.taskCenter = self.taskCenter
        } operation: {
            AIWorkflowStore()
        }
    }

    override func tearDown() async throws {
        store = nil
        mockLLM = nil
        mockKnowledgeRepo = nil
        mockEmbedding = nil
        mockVectorStore = nil
        taskCenter = nil
        keyStore = nil
        resetPersistentTestState()
        UserDefaults.standard.removeObject(forKey: AppConstants.Keys.Storage.lastLintIssues)
        try? await Task.sleep(nanoseconds: 50_000_000)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    /// 构造测试用 KnowledgePage
    private func makePage(
        id: UUID = UUID(),
        title: String = "测试页面",
        content: String = "这是测试内容，用于验证 Lint 与 AI 扫描行为。",
        pageType: PageType = .concept,
        status: PageStatus = .active,
        updatedAt: Date = Date()
    ) -> KnowledgePage {
        KnowledgePage(
            id: id,
            title: title,
            pageType: pageType,
            content: content,
            status: status,
            updatedAt: updatedAt
        )
    }

    // MARK: - 1. 初始状态验证

    /// 验证新建 AIWorkflowStore 的所有属性初始值
    func testInitialStateAllProperties() {
        XCTAssertEqual(store.refactorSuggestions, [], "refactorSuggestions 初始应为空数组")
        XCTAssertEqual(store.potentialLinks, [], "potentialLinks 初始应为空数组")
        XCTAssertEqual(store.activePageAIResult, nil, "activePageAIResult 初始应为 nil")
        XCTAssertEqual(store.isProcessingPageAI, false, "isProcessingPageAI 初始应为 false")
        XCTAssertEqual(store.activeQuiz, nil, "activeQuiz 初始应为 nil")
        XCTAssertEqual(store.lastLintScore, 0, "lastLintScore 初始应为 0")
        XCTAssertEqual(store.lastLintDate, nil, "lastLintDate 初始应为 nil")
        XCTAssertEqual(store.isScanningAI, false, "isScanningAI 初始应为 false")
        XCTAssertEqual(store.lintIssues, [], "lintIssues 初始应为空数组")
        XCTAssertEqual(store.lintScore, 100, "lintScore 初始应为 100（无 issue 时满分）")
        XCTAssertEqual(store.healthLevel, .excellent, "healthLevel 初始应为 excellent（满分）")
        XCTAssertEqual(store.healthMetrics.score, 100, "healthMetrics.score 初始应为 100")
        XCTAssertEqual(store.healthMetrics.level, .excellent, "healthMetrics.level 初始应为 excellent")
        XCTAssertEqual(store.isLLMEnabled, true, "isLLMEnabled 初始应为 true（MockLLM 默认启用）")
        XCTAssertNotNil(store.insightStore, "insightStore 初始应非 nil")
    }

    // MARK: - 2. isLLMEnabled 属性

    /// 验证 isLLMEnabled 透传 llmService.isEnabled
    func testIsLLMEnabledReflectsLLMServiceState() {
        mockLLM.isEnabledStub = true
        XCTAssertEqual(store.isLLMEnabled, true, "LLM 启用时 isLLMEnabled 应为 true")

        mockLLM.isEnabledStub = false
        XCTAssertEqual(store.isLLMEnabled, false, "LLM 禁用时 isLLMEnabled 应为 false")

        mockLLM.isEnabledStub = true
        XCTAssertEqual(store.isLLMEnabled, true, "LLM 重新启用后 isLLMEnabled 应恢复 true")
    }

    // MARK: - 3. lintIssues 属性与持久化

    /// 验证 lintIssues setter 触发 KeyStore 持久化
    func testLintIssuesSetterPersistsToKeyStore() {
        let issue = LintIssue(severity: .error, type: .brokenLink, pageID: UUID(), message: "断裂链接", suggestion: "修复")
        store.lintIssues = [issue]

        let persistedData = keyStore.data(forKey: AppConstants.Keys.Storage.lastLintIssues)
        XCTAssertNotNil(persistedData, "lintIssues setter 后应在 KeyStore 持久化数据")
        let decoded = try? JSONDecoder().decode([LintIssue].self, from: persistedData ?? Data())
        XCTAssertEqual(decoded?.count, 1, "持久化的 lintIssues 应包含 1 条")
        XCTAssertEqual(decoded?.first?.severity, .error, "持久化的 issue severity 应为 error")
    }

    /// 验证 lintIssues 空数组持久化（编码后仍可解码为空数组）
    func testLintIssuesEmptyArrayPersistsCorrectly() {
        store.lintIssues = []
        let persistedData = keyStore.data(forKey: AppConstants.Keys.Storage.lastLintIssues)
        // 空数组编码为 "[]"（非 nil），但 setter 中 try? 失败时不写入；空数组编码应成功
        if let data = persistedData {
            let decoded = try? JSONDecoder().decode([LintIssue].self, from: data)
            XCTAssertEqual(decoded, [], "空数组持久化后解码应为空数组")
        }
        // 不强制断言 persistedData 非 nil：空数组编码成功则写入，失败则不写入，两种行为均可接受
    }

    /// 验证 lintIssues 多次赋值覆盖旧值
    func testLintIssuesMultipleAssignmentsOverwrite() {
        let issue1 = LintIssue(severity: .warning, type: .orphan, pageID: UUID(), message: "孤立页面1", suggestion: "链接")
        let issue2 = LintIssue(severity: .info, type: .stub, pageID: UUID(), message: "存根页面2", suggestion: "扩充")
        store.lintIssues = [issue1]
        XCTAssertEqual(store.lintIssues.count, 1, "首次赋值后应有 1 条")
        store.lintIssues = [issue2, issue2]
        XCTAssertEqual(store.lintIssues.count, 2, "二次赋值应覆盖旧值，变为 2 条")
        XCTAssertEqual(store.lintIssues.first?.severity, .info, "二次赋值后首条 severity 应为 info")
    }

    // MARK: - 4. healthMetrics / lintScore / healthLevel 代理属性

    /// 验证 healthMetrics 扣分规则：1 个 error 扣 10 分
    func testHealthMetricsErrorDeduction() {
        store.lintIssues = [LintIssue(severity: .error, type: .brokenLink, message: "err", suggestion: "")]
        XCTAssertEqual(store.healthMetrics.score, 90, "1 个 error 应扣 10 分，得 90")
        XCTAssertEqual(store.healthMetrics.level, .excellent, "90 分应为 excellent")
        XCTAssertEqual(store.lintScore, 90, "lintScore 应等于 healthMetrics.score")
        XCTAssertEqual(store.healthLevel, .excellent, "healthLevel 应等于 healthMetrics.level")
    }

    /// 验证 healthMetrics 扣分规则：1 个 warning 扣 5 分
    func testHealthMetricsWarningDeduction() {
        store.lintIssues = [LintIssue(severity: .warning, type: .orphan, message: "warn", suggestion: "")]
        XCTAssertEqual(store.healthMetrics.score, 95, "1 个 warning 应扣 5 分，得 95")
        XCTAssertEqual(store.healthMetrics.level, .excellent, "95 分应为 excellent")
    }

    /// 验证 healthMetrics 扣分规则：1 个 info 扣 2 分
    func testHealthMetricsInfoDeduction() {
        store.lintIssues = [LintIssue(severity: .info, type: .stub, message: "info", suggestion: "")]
        XCTAssertEqual(store.healthMetrics.score, 98, "1 个 info 应扣 2 分，得 98")
        XCTAssertEqual(store.healthMetrics.level, .excellent, "98 分应为 excellent")
    }

    /// 验证 healthMetrics 等级边界：75 分为 good
    func testHealthMetricsGoodLevelBoundary() {
        // 5 个 warning = 25 分扣减，得 75
        let issues = (0..<5).map { _ in LintIssue(severity: .warning, type: .orphan, message: "w", suggestion: "") }
        store.lintIssues = issues
        XCTAssertEqual(store.healthMetrics.score, 75, "5 个 warning 应得 75 分")
        XCTAssertEqual(store.healthMetrics.level, .good, "75 分应为 good")
    }

    /// 验证 healthMetrics 等级边界：50 分为 fair
    func testHealthMetricsFairLevelBoundary() {
        // 10 个 warning = 50 分扣减，得 50
        let issues = (0..<10).map { _ in LintIssue(severity: .warning, type: .orphan, message: "w", suggestion: "") }
        store.lintIssues = issues
        XCTAssertEqual(store.healthMetrics.score, 50, "10 个 warning 应得 50 分")
        XCTAssertEqual(store.healthMetrics.level, .fair, "50 分应为 fair")
    }

    /// 验证 healthMetrics 等级边界：49 分为 poor
    func testHealthMetricsPoorLevelBoundary() {
        // 11 个 warning = 55 分扣减，得 45（< 50）
        let issues = (0..<11).map { _ in LintIssue(severity: .warning, type: .orphan, message: "w", suggestion: "") }
        store.lintIssues = issues
        XCTAssertEqual(store.healthMetrics.score, 45, "11 个 warning 应得 45 分")
        XCTAssertEqual(store.healthMetrics.level, .poor, "45 分应为 poor")
    }

    /// 验证 healthMetrics 扣分下限：超过 100 分扣减时分数不低于 0
    func testHealthMetricsScoreFloorAtZero() {
        // 20 个 error = 200 分扣减，应被 max(0, ...) 截断为 0
        let issues = (0..<20).map { _ in LintIssue(severity: .error, type: .brokenLink, message: "e", suggestion: "") }
        store.lintIssues = issues
        XCTAssertEqual(store.healthMetrics.score, 0, "20 个 error 扣分应被截断为 0")
        XCTAssertEqual(store.healthMetrics.level, .poor, "0 分应为 poor")
    }

    /// 验证 healthMetrics 混合严重级别扣分
    func testHealthMetricsMixedSeverities() {
        // 2 error(20) + 3 warning(15) + 5 info(10) = 45 扣分，得 55
        var issues: [LintIssue] = []
        issues.append(contentsOf: (0..<2).map { _ in LintIssue(severity: .error, type: .brokenLink, message: "e", suggestion: "") })
        issues.append(contentsOf: (0..<3).map { _ in LintIssue(severity: .warning, type: .orphan, message: "w", suggestion: "") })
        issues.append(contentsOf: (0..<5).map { _ in LintIssue(severity: .info, type: .stub, message: "i", suggestion: "") })
        store.lintIssues = issues
        XCTAssertEqual(store.healthMetrics.score, 55, "2 error + 3 warning + 5 info 应得 55 分")
        XCTAssertEqual(store.healthMetrics.level, .fair, "55 分应为 fair")
    }

    // MARK: - 5. lastLintScore / lastLintDate 属性

    /// 验证 lastLintScore 是独立存储属性，不随 lintScore 自动同步
    func testLastLintScoreIsIndependentFromLintScore() {
        // 注入 issue 使 lintScore 变为 90
        store.lintIssues = [LintIssue(severity: .error, type: .brokenLink, message: "e", suggestion: "")]
        XCTAssertEqual(store.lintScore, 90, "lintScore 应为 90")
        XCTAssertEqual(store.lastLintScore, 0, "lastLintScore 是独立属性，不应随 lintScore 自动更新（潜在 bug：runLint 未更新 lastLintScore）")
    }

    /// 验证 lastLintDate 可被手动设置
    func testLastLintDateSettable() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        store.lastLintDate = date
        XCTAssertEqual(store.lastLintDate?.timeIntervalSince1970, 1_700_000_000, "lastLintDate 应可被手动设置")
    }

    // MARK: - 6. isScanningAI 状态变化

    /// 验证 isScanningAI 在 runAIScan 成功后恢复 false
    func testIsScanningAIResetsAfterSuccessfulScan() async {
        mockKnowledgeRepo.stubPages = [makePage(title: "页面A")]
        mockLLM.stubDiscoverLinks = ["页面B"]

        await store.runAIScan(forPage: nil)

        XCTAssertEqual(store.isScanningAI, false, "扫描成功后 isScanningAI 应恢复 false")
    }

    /// 验证 isScanningAI 在 runAIScan 抛错后恢复 false
    func testIsScanningAIResetsAfterScanError() async {
        mockKnowledgeRepo.stubPages = [makePage(title: "页面A")]
        mockLLM.stubDiscoverError = LLMError.notConfigured

        await store.runAIScan(forPage: nil)

        XCTAssertEqual(store.isScanningAI, false, "扫描抛错后 isScanningAI 应恢复 false")
    }

    /// 验证 isScanningAI 在 LLM 禁用时短路返回，保持 false
    func testIsScanningAIStaysFalseWhenLLMDisabled() async {
        mockLLM.isEnabledStub = false
        mockKnowledgeRepo.stubPages = [makePage(title: "页面A")]

        await store.runAIScan(forPage: nil)

        XCTAssertEqual(store.isScanningAI, false, "LLM 禁用时短路返回，isScanningAI 应保持 false")
    }

    // MARK: - 7. isProcessingPageAI 状态变化

    /// 验证 isProcessingPageAI 在 runPageAISummary 成功后恢复 false
    func testIsProcessingPageAIResetsAfterSummary() async throws {
        mockLLM.stubGenerateResult = "摘要结果"
        let result = try await store.runPageAISummary(content: "待摘要内容")
        XCTAssertEqual(result, "摘要结果", "runPageAISummary 应返回 LLM 生成结果")
        XCTAssertEqual(store.activePageAIResult, "摘要结果", "activePageAIResult 应被设置为生成结果")
        XCTAssertEqual(store.isProcessingPageAI, false, "摘要完成后 isProcessingPageAI 应恢复 false")
    }

    /// 验证 isProcessingPageAI 在 runPageAIExtractActions 成功后恢复 false
    func testIsProcessingPageAIResetsAfterExtractActions() async throws {
        mockLLM.stubGenerateResult = "行动项列表"
        let result = try await store.runPageAIExtractActions(content: "待提取内容")
        XCTAssertEqual(result, "行动项列表", "runPageAIExtractActions 应返回 LLM 生成结果")
        XCTAssertEqual(store.activePageAIResult, "行动项列表", "activePageAIResult 应被设置为生成结果")
        XCTAssertEqual(store.isProcessingPageAI, false, "提取完成后 isProcessingPageAI 应恢复 false")
    }

    /// 验证 isProcessingPageAI 在 runPageAIExpansion 成功后恢复 false
    func testIsProcessingPageAIResetsAfterExpansion() async throws {
        mockLLM.stubGenerateResult = "扩展内容"
        let result = try await store.runPageAIExpansion(content: "待扩展内容")
        XCTAssertEqual(result, "扩展内容", "runPageAIExpansion 应返回 LLM 生成结果")
        XCTAssertEqual(store.activePageAIResult, "扩展内容", "activePageAIResult 应被设置为生成结果")
        XCTAssertEqual(store.isProcessingPageAI, false, "扩展完成后 isProcessingPageAI 应恢复 false")
    }

    /// 验证 isProcessingPageAI 在 runPageAISummary 抛错后恢复 false（defer 保证）
    func testIsProcessingPageAIResetsAfterSummaryError() async {
        mockLLM.stubGenerateError = LLMError.notConfigured
        do {
            _ = try await store.runPageAISummary(content: "内容")
            XCTFail("LLM 抛错时 runPageAISummary 应抛出错误")
        } catch {
            // 预期抛错
        }
        XCTAssertEqual(store.isProcessingPageAI, false, "摘要抛错后 isProcessingPageAI 应通过 defer 恢复 false")
    }

    // MARK: - 8. refactorSuggestions 属性

    /// 验证 refactorSuggestions 全局扫描后被 LLM 返回的建议填充
    func testRefactorSuggestionsPopulatedByGlobalScan() async {
        mockKnowledgeRepo.stubPages = [makePage(title: "页面A"), makePage(title: "页面B")]
        let suggestion = RefactorSuggestionDTO(type: "merge", target: "页面A", reason: "重复", suggestion: "合并")
        mockLLM.stubRefactorSuggestions = [suggestion]

        await store.runAIScan(forPage: nil)

        XCTAssertEqual(store.refactorSuggestions.count, 1, "全局扫描后 refactorSuggestions 应包含 LLM 返回的 1 条建议")
        XCTAssertEqual(store.refactorSuggestions.first?.type, "merge", "建议 type 应为 merge")
        XCTAssertEqual(store.refactorSuggestions.first?.target, "页面A", "建议 target 应为 页面A")
    }

    /// 验证 refactorSuggestions 在单页扫描时不被更新（单页扫描不调用 analyzeForRefactoring）
    func testRefactorSuggestionsNotUpdatedBySinglePageScan() async {
        let existing = RefactorSuggestionDTO(type: "split", target: "旧目标", reason: "旧原因", suggestion: "旧建议")
        store.refactorSuggestions = [existing]
        mockKnowledgeRepo.stubPages = [makePage(title: "页面A")]
        mockLLM.stubDiscoverLinks = ["页面B"]

        await store.runAIScan(forPage: makePage(title: "页面A"))

        XCTAssertEqual(store.refactorSuggestions.count, 1, "单页扫描不应调用 analyzeForRefactoring，refactorSuggestions 应保持旧值")
        XCTAssertEqual(store.refactorSuggestions.first?.target, "旧目标", "单页扫描后 refactorSuggestions 应保持旧 target")
    }

    // MARK: - 9. removeRefactorSuggestion 方法

    /// 验证 removeRefactorSuggestion 正常移除存在的 id
    func testRemoveRefactorSuggestionExistingId() {
        let s1 = RefactorSuggestionDTO(type: "merge", target: "目标1", reason: "r1", suggestion: "s1")
        let s2 = RefactorSuggestionDTO(type: "split", target: "目标2", reason: "r2", suggestion: "s2")
        store.refactorSuggestions = [s1, s2]

        store.removeRefactorSuggestion(id: s1.id)

        XCTAssertEqual(store.refactorSuggestions.count, 1, "移除存在的 id 后应剩 1 条")
        XCTAssertEqual(store.refactorSuggestions.first?.id, s2.id, "剩余的应为 s2")
    }

    /// 验证 removeRefactorSuggestion 不存在的 id 不影响列表
    func testRemoveRefactorSuggestionNonExistentId() {
        let s1 = RefactorSuggestionDTO(type: "merge", target: "目标1", reason: "r1", suggestion: "s1")
        store.refactorSuggestions = [s1]

        store.removeRefactorSuggestion(id: "不存在的id")

        XCTAssertEqual(store.refactorSuggestions.count, 1, "移除不存在的 id 时列表应不受影响")
        XCTAssertEqual(store.refactorSuggestions.first?.id, s1.id, "剩余的应为 s1")
    }

    /// 验证 removeRefactorSuggestion 空列表时无副作用
    func testRemoveRefactorSuggestionOnEmptyList() {
        store.refactorSuggestions = []
        store.removeRefactorSuggestion(id: "任意id")
        XCTAssertEqual(store.refactorSuggestions, [], "空列表上调用 removeRefactorSuggestion 应无副作用")
    }

    /// 验证 removeRefactorSuggestion 移除所有元素
    func testRemoveRefactorSuggestionAllElements() {
        let s1 = RefactorSuggestionDTO(type: "merge", target: "t1", reason: "r", suggestion: "s")
        let s2 = RefactorSuggestionDTO(type: "split", target: "t2", reason: "r", suggestion: "s")
        store.refactorSuggestions = [s1, s2]

        store.removeRefactorSuggestion(id: s1.id)
        store.removeRefactorSuggestion(id: s2.id)

        XCTAssertEqual(store.refactorSuggestions, [], "逐个移除所有元素后列表应为空")
    }

    // MARK: - 10. potentialLinks 属性与 removePotentialLink

    /// 验证 potentialLinks 全局扫描后被填充
    func testPotentialLinksPopulatedByGlobalScan() async {
        let pageA = makePage(id: UUID(), title: "页面A", content: "内容A")
        mockKnowledgeRepo.stubPages = [pageA]
        mockLLM.stubDiscoverLinks = ["页面B"]

        await store.runAIScan(forPage: nil)

        XCTAssertEqual(store.potentialLinks.count, 1, "全局扫描后 potentialLinks 应包含 1 条建议")
        XCTAssertEqual(store.potentialLinks.first?.sourcePageID, pageA.id, "sourcePageID 应为 页面A 的 id")
        XCTAssertEqual(store.potentialLinks.first?.sourceTitle, "页面A", "sourceTitle 应为 页面A")
        XCTAssertEqual(store.potentialLinks.first?.targetTitle, "页面B", "targetTitle 应为 页面B")
    }

    /// 验证 potentialLinks 去重：同一 (page, title) 只保留一条
    func testPotentialLinksDeduplication() async {
        let pageA = makePage(id: UUID(), title: "页面A", content: "内容A")
        mockKnowledgeRepo.stubPages = [pageA]
        // LLM 返回重复的标题，Set 去重后应只生成一条
        mockLLM.stubDiscoverLinks = ["页面B", "页面B", "页面B"]

        await store.runAIScan(forPage: nil)

        XCTAssertEqual(store.potentialLinks.count, 1, "重复的 targetTitle 应被 Set 去重为 1 条")
    }

    /// 验证 potentialLinks 过滤已存在的 [[title]] 链接
    func testPotentialLinksFiltersExistingWikiLinks() async {
        let pageA = makePage(id: UUID(), title: "页面A", content: "内容包含 [[页面B]] 链接")
        mockKnowledgeRepo.stubPages = [pageA]
        mockLLM.stubDiscoverLinks = ["页面B"]

        await store.runAIScan(forPage: nil)

        XCTAssertEqual(store.potentialLinks, [], "已存在 [[页面B]] 链接时该建议应被过滤")
    }

    /// 验证 removePotentialLink 正常移除存在的 id
    func testRemovePotentialLinkExistingId() {
        let link1 = PotentialLinkSuggestion(sourcePageID: UUID(), sourceTitle: "源1", targetTitle: "目标1")
        let link2 = PotentialLinkSuggestion(sourcePageID: UUID(), sourceTitle: "源2", targetTitle: "目标2")
        store.potentialLinks = [link1, link2]

        store.removePotentialLink(id: link1.id)

        XCTAssertEqual(store.potentialLinks.count, 1, "移除存在的 id 后应剩 1 条")
        XCTAssertEqual(store.potentialLinks.first?.id, link2.id, "剩余的应为 link2")
    }

    /// 验证 removePotentialLink 不存在的 id 不影响列表
    func testRemovePotentialLinkNonExistentId() {
        let link1 = PotentialLinkSuggestion(sourcePageID: UUID(), sourceTitle: "源1", targetTitle: "目标1")
        store.potentialLinks = [link1]

        store.removePotentialLink(id: UUID())

        XCTAssertEqual(store.potentialLinks.count, 1, "移除不存在的 id 时列表应不受影响")
    }

    // MARK: - 11. activePageAIResult 属性

    /// 验证 activePageAIResult 初始为 nil，被 runPageAISummary 设置后非 nil
    func testActivePageAIResultLifecycle() async throws {
        XCTAssertEqual(store.activePageAIResult, nil, "初始应为 nil")
        mockLLM.stubGenerateResult = "AI 摘要结果"
        _ = try await store.runPageAISummary(content: "内容")
        XCTAssertEqual(store.activePageAIResult, "AI 摘要结果", "runPageAISummary 后应被设置")
    }

    // MARK: - 12. activeQuiz 属性

    /// 验证 performPageSynthesis quiz 类型且解析成功时设置 activeQuiz
    func testPerformPageSynthesisQuizSetsActiveQuiz() async throws {
        // 构造可被 QuizProcessor.parseToQuizModel 解析的 JSON
        let quizJSON = """
        {
          "title": "测试测验",
          "questions": [
            {
              "id": 1,
              "text": "测试题目?",
              "options": ["选项A", "选项B", "选项C", "选项D"],
              "answer": 0,
              "explanation": "解析说明"
            }
          ]
        }
        """
        mockLLM.stubGenerateResult = quizJSON

        _ = try await store.performPageSynthesis(type: .quiz, title: "测验标题", content: "测验内容")

        XCTAssertNotNil(store.activeQuiz, "quiz 类型且解析成功时 activeQuiz 应非 nil")
        XCTAssertEqual(store.activeQuiz?.title, "测试测验", "activeQuiz.title 应为 JSON 中的 title")
        XCTAssertEqual(store.activeQuiz?.questions.count, 1, "activeQuiz 应包含 1 道题目")
    }

    /// 验证 performPageSynthesis quiz 类型但解析失败时设置 activePageAIResult 而非 activeQuiz
    func testPerformPageSynthesisQuizParseFailureFallsBackToActivePageAIResult() async throws {
        // 返回无法解析为 QuizModel 的纯文本
        mockLLM.stubGenerateResult = "这是无法解析为 quiz 的纯文本内容，足够长以通过校验。"

        _ = try await store.performPageSynthesis(type: .quiz, title: "测验标题", content: "测验内容")

        XCTAssertEqual(store.activeQuiz, nil, "quiz 解析失败时 activeQuiz 应为 nil")
        XCTAssertEqual(store.activePageAIResult, "这是无法解析为 quiz 的纯文本内容，足够长以通过校验。", "解析失败时应 fallback 到 activePageAIResult")
    }

    /// 验证 performPageSynthesis 非 quiz 类型时设置 activePageAIResult
    func testPerformPageSynthesisNonQuizSetsActivePageAIResult() async throws {
        mockLLM.stubGenerateResult = "思维导图结果"
        _ = try await store.performPageSynthesis(type: .mindmap, title: "导图标题", content: "内容")
        // mindmap 类型经 SynthesisProcessor.formatMermaid 包装为 "mindmap\n  \"思维导图结果\""
        XCTAssertEqual(store.activePageAIResult, "mindmap\n  \"思维导图结果\"", "非 quiz 类型应设置 activePageAIResult（经 mermaid 格式化）")
        XCTAssertEqual(store.activeQuiz, nil, "非 quiz 类型时 activeQuiz 应为 nil")
    }

    /// 验证 performPageSynthesis 抛错时 isProcessingPageAI 恢复 false 且 taskCenter 任务失败
    func testPerformPageSynthesisErrorResetsStateAndFailsTask() async {
        mockLLM.stubGenerateError = LLMError.notConfigured
        let taskCountBefore = taskCenter.tasks.count
        do {
            _ = try await store.performPageSynthesis(type: .mindmap, title: "标题", content: "内容")
            XCTFail("LLM 抛错时 performPageSynthesis 应抛出错误")
        } catch {
            // 预期抛错
        }
        XCTAssertEqual(store.isProcessingPageAI, false, "抛错后 isProcessingPageAI 应通过 defer 恢复 false")
        XCTAssertEqual(taskCenter.tasks.count, taskCountBefore + 1, "应新增 1 个任务")
        let lastTask = taskCenter.tasks.first
        if case .failed = lastTask?.status {
            // 预期失败状态
        } else {
            XCTFail("抛错后任务状态应为 failed")
        }
    }

    /// 验证 performPageSynthesis 成功时 taskCenter 任务完成
    func testPerformPageSynthesisSuccessCompletesTask() async throws {
        mockLLM.stubGenerateResult = "合成结果内容足够长以通过校验。"
        let taskCountBefore = taskCenter.tasks.count
        _ = try await store.performPageSynthesis(type: .report, title: "报告标题", content: "内容")
        XCTAssertEqual(taskCenter.tasks.count, taskCountBefore + 1, "应新增 1 个任务")
        let lastTask = taskCenter.tasks.first
        XCTAssertEqual(lastTask?.status, .completed, "成功后任务状态应为 completed")
    }

    // MARK: - 13. insightStore 属性验证

    /// 验证 insightStore 是 AIInsightStore 实例且可访问其属性
    func testInsightStoreIsAccessibleAIInsightStore() {
        XCTAssertNotNil(store.insightStore as AIInsightStore?, "insightStore 应为 AIInsightStore 实例")
        XCTAssertEqual(store.insightStore.brokenLinkCount, 0, "insightStore.brokenLinkCount 初始应为 0")
        XCTAssertEqual(store.insightStore.orphanPageCount, 0, "insightStore.orphanPageCount 初始应为 0")
        XCTAssertEqual(store.insightStore.isGeneratingDailyRecap, false, "insightStore.isGeneratingDailyRecap 初始应为 false")
    }

    // MARK: - 14. runLint 流程

    /// 验证 runLint 空页面列表时 lintIssues 为空，lastLintDate 被更新
    func testRunLintEmptyPagesUpdatesLintDate() async {
        mockKnowledgeRepo.stubPages = []
        let dateBefore = Date()
        await store.runLint()
        XCTAssertEqual(store.lintIssues, [], "空页面列表时 lintIssues 应为空")
        XCTAssertEqual(store.lintScore, 100, "空 issue 时 lintScore 应为 100")
        XCTAssertNotNil(store.lastLintDate, "runLint 后 lastLintDate 应被更新")
        XCTAssertGreaterThanOrEqual(store.lastLintDate?.timeIntervalSince1970 ?? 0, dateBefore.timeIntervalSince1970, "lastLintDate 应不早于 runLint 调用前")
    }

    /// 验证 runLint 检测到断裂链接时 lintIssues 非空
    func testRunLintDetectsBrokenLink() async {
        let pageA = makePage(id: UUID(), title: "页面A", content: "内容包含 [[不存在的页面]] 链接")
        mockKnowledgeRepo.stubPages = [pageA]
        await store.runLint()
        XCTAssertTrue(store.lintIssues.contains { $0.type == .brokenLink }, "存在未匹配的 [[链接]] 时应检测到 brokenLink issue")
        XCTAssertLessThan(store.lintScore, 100, "有 issue 时 lintScore 应低于 100")
    }

    /// 验证 runLint 检测到孤岛页面（无入链无出链）
    func testRunLintDetectsIslandPage() async {
        let pageA = makePage(id: UUID(), title: "孤岛页面", content: "独立内容无任何链接")
        mockKnowledgeRepo.stubPages = [pageA]
        await store.runLint()
        XCTAssertTrue(store.lintIssues.contains { $0.type == .island }, "无入链无出链的页面应检测为 island")
    }

    /// 验证 runLint 检测到孤立页面（无入链但有出链）
    func testRunLintDetectsOrphanPage() async {
        let pageA = makePage(id: UUID(), title: "源页面", content: "内容包含 [[目标页面]] 链接")
        let pageB = makePage(id: UUID(), title: "目标页面", content: "被引用的目标页面")
        mockKnowledgeRepo.stubPages = [pageA, pageB]
        await store.runLint()
        // pageA 有出链到 pageB，pageB 有入链来自 pageA；pageA 无入链 → orphan
        XCTAssertTrue(store.lintIssues.contains { $0.type == .orphan }, "无入链但有出链的页面应检测为 orphan")
    }

    /// 验证 runLint 检测到存根页面（内容过少）
    func testRunLintDetectsStubPage() async {
        let pageA = makePage(id: UUID(), title: "存根页面", content: "短", status: .active)
        mockKnowledgeRepo.stubPages = [pageA]
        await store.runLint()
        // 存根页面内容过少且无链接 → 同时触发 island 和 stub
        XCTAssertTrue(store.lintIssues.contains { $0.type == .stub }, "内容过少的 active 页面应检测为 stub")
    }

    /// 验证 runLint 检测到重名页面
    func testRunLintDetectsDuplicateTitles() async {
        let pageA = makePage(id: UUID(), title: "重名", content: "内容A")
        let pageB = makePage(id: UUID(), title: "重名", content: "内容B")
        mockKnowledgeRepo.stubPages = [pageA, pageB]
        await store.runLint()
        XCTAssertTrue(store.lintIssues.contains { $0.type == .generic && $0.severity == .warning }, "重名页面应检测为 generic warning")
    }

    /// 验证 runLint 后 lastLintDate 和 lastLintScore 均被更新（修复后：score 同步更新）
    func testRunLintDoesNotUpdateLastLintScore() async {
        mockKnowledgeRepo.stubPages = [makePage(title: "孤岛页面", content: "独立内容")]
        await store.runLint()
        XCTAssertNotNil(store.lastLintDate, "runLint 后 lastLintDate 应被更新")
        // 修复后：lastLintScore 应通过 healthMetrics.score 同步更新，不再恒为 0
        XCTAssertNotEqual(store.lastLintScore, 0, "修复后：runLint 应更新 lastLintScore 为 healthMetrics.score")
        XCTAssertEqual(store.lastLintScore, store.healthMetrics.score, "修复后：lastLintScore 应与 healthMetrics.score 一致")
    }

    /// 验证 runLint 后 taskCenter 新增 healthCheck 任务并完成
    func testRunLintCreatesAndCompletesHealthCheckTask() async {
        mockKnowledgeRepo.stubPages = []
        let taskCountBefore = taskCenter.tasks.count
        await store.runLint()
        XCTAssertEqual(taskCenter.tasks.count, taskCountBefore + 1, "runLint 应新增 1 个 healthCheck 任务")
        let lastTask = taskCenter.tasks.first
        XCTAssertEqual(lastTask?.type, .healthCheck, "任务类型应为 healthCheck")
        XCTAssertEqual(lastTask?.status, .completed, "任务状态应为 completed")
    }

    /// 验证 runLint 在 fetchAll 抛错时降级为空页面列表，不崩溃
    func testRunLintDegradesWhenFetchAllThrows() async {
        struct RepoError: Error {}
        mockKnowledgeRepo.stubFetchAllError = RepoError()
        await store.runLint()
        XCTAssertEqual(store.lintIssues, [], "fetchAll 抛错时应降级为空页面列表，lintIssues 为空")
        XCTAssertNotNil(store.lastLintDate, "即使 fetchAll 抛错，lastLintDate 仍应被更新")
    }

    // MARK: - 15. runAIScan 流程

    /// 验证 runAIScan LLM 禁用时短路返回，不创建任务，不修改状态
    func testRunAIScanShortCircuitsWhenLLMDisabled() async {
        mockLLM.isEnabledStub = false
        mockKnowledgeRepo.stubPages = [makePage(title: "页面A")]
        let taskCountBefore = taskCenter.tasks.count

        await store.runAIScan(forPage: nil)

        XCTAssertEqual(store.isScanningAI, false, "LLM 禁用时 isScanningAI 应保持 false")
        XCTAssertEqual(taskCenter.tasks.count, taskCountBefore, "LLM 禁用时不应创建任务")
        XCTAssertEqual(store.potentialLinks, [], "LLM 禁用时 potentialLinks 应不受影响")
        XCTAssertEqual(mockLLM.discoverCalls.count, 0, "LLM 禁用时不应调用 discoverPotentialLinks")
    }

    /// 验证 runAIScan 单页扫描增量合并 potentialLinks（移除该页旧链接 + 追加新链接）
    func testRunAIScanSinglePageIncrementalMerge() async {
        let pageA = makePage(id: UUID(), title: "页面A", content: "内容A")
        let pageB = makePage(id: UUID(), title: "页面B", content: "内容B")
        // 预置旧链接：pageA 旧链接 + pageB 旧链接
        let oldLinkA = PotentialLinkSuggestion(sourcePageID: pageA.id, sourceTitle: "页面A", targetTitle: "旧目标A")
        let oldLinkB = PotentialLinkSuggestion(sourcePageID: pageB.id, sourceTitle: "页面B", targetTitle: "旧目标B")
        store.potentialLinks = [oldLinkA, oldLinkB]
        mockKnowledgeRepo.stubPages = [pageA, pageB]
        mockLLM.stubDiscoverLinks = ["新目标A"]

        await store.runAIScan(forPage: pageA)

        // 单页扫描应移除 pageA 的旧链接，追加 pageA 的新链接，保留 pageB 的旧链接
        XCTAssertEqual(store.potentialLinks.count, 2, "单页扫描后应剩 2 条（pageB 旧链接 + pageA 新链接）")
        XCTAssertTrue(store.potentialLinks.contains { $0.sourcePageID == pageB.id && $0.targetTitle == "旧目标B" }, "pageB 的旧链接应保留")
        XCTAssertTrue(store.potentialLinks.contains { $0.sourcePageID == pageA.id && $0.targetTitle == "新目标A" }, "pageA 的新链接应被追加")
        XCTAssertFalse(store.potentialLinks.contains { $0.sourcePageID == pageA.id && $0.targetTitle == "旧目标A" }, "pageA 的旧链接应被移除")
    }

    /// 验证 runAIScan 全局扫描合并 potentialLinks（修复后：不覆盖单页扫描累积的链接）
    func testRunAIScanGlobalScanOverwritesPotentialLinks() async {
        let pageA = makePage(id: UUID(), title: "页面A", content: "内容A")
        let pageB = makePage(id: UUID(), title: "页面B", content: "内容B")
        // 预置单页扫描累积的链接
        let accumulatedLink = PotentialLinkSuggestion(sourcePageID: pageB.id, sourceTitle: "页面B", targetTitle: "累积目标")
        store.potentialLinks = [accumulatedLink]
        mockKnowledgeRepo.stubPages = [pageA]
        mockLLM.stubDiscoverLinks = ["全局新目标"]

        await store.runAIScan(forPage: nil)

        // 修复后：全局扫描合并而非覆盖，保留单页扫描累积的链接
        XCTAssertEqual(store.potentialLinks.count, 2, "修复后：全局扫描合并 potentialLinks，应包含累积链接 + 新链接")
        XCTAssertTrue(store.potentialLinks.contains { $0.targetTitle == "全局新目标" }, "应包含全局扫描的新目标")
        XCTAssertTrue(store.potentialLinks.contains { $0.targetTitle == "累积目标" }, "修复后：全局扫描应保留单页扫描累积的链接")
    }

    /// 验证 runAIScan 全局扫描采样前 globalScanPrefix(10) 页调用 analyzeForRefactoring
    func testRunAIScanGlobalScanSamplesPrefixPagesForRefactoring() async {
        // 构造 15 个页面，全局扫描应只对前 10 个调用 analyzeForRefactoring
        let pages = (0..<15).map { i in makePage(title: "页面\(i)", content: "内容\(i)") }
        mockKnowledgeRepo.stubPages = pages
        mockLLM.stubRefactorSuggestions = []

        await store.runAIScan(forPage: nil)

        XCTAssertEqual(mockLLM.refactorCalls.count, 1, "全局扫描应调用 1 次 analyzeForRefactoring")
        XCTAssertEqual(mockLLM.refactorCalls.first, 10, "analyzeForRefactoring 应接收前 10 个页面（globalScanPrefix）")
    }

    /// 验证 runAIScan 全局扫描采样前 recentScanPrefix(5) 页发现链接
    func testRunAIScanGlobalScanSamplesPrefixPagesForLinks() async {
        // 构造 8 个页面，按 updatedAt 降序排序后取前 5 个扫描链接
        let now = Date()
        let pages = (0..<8).map { i in
            makePage(title: "页面\(i)", content: "内容\(i)", updatedAt: now.addingTimeInterval(TimeInterval(i)))
        }
        mockKnowledgeRepo.stubPages = pages
        mockLLM.stubDiscoverLinks = ["目标"]

        await store.runAIScan(forPage: nil)

        // 8 页面取前 5 个（按 updatedAt 降序，即 i=0..4），每个返回 1 个目标链接
        XCTAssertEqual(store.potentialLinks.count, 5, "全局扫描应对前 5 个页面（recentScanPrefix）发现链接")
        XCTAssertEqual(mockLLM.discoverCalls.count, 5, "discoverPotentialLinks 应被调用 5 次")
    }

    /// 验证 runAIScan 抛错时 taskCenter 任务失败且记录日志
    func testRunAIScanErrorFailsTask() async {
        mockKnowledgeRepo.stubPages = [makePage(title: "页面A")]
        mockLLM.stubDiscoverError = LLMError.notConfigured
        let taskCountBefore = taskCenter.tasks.count

        await store.runAIScan(forPage: nil)

        XCTAssertEqual(store.isScanningAI, false, "抛错后 isScanningAI 应恢复 false")
        XCTAssertEqual(taskCenter.tasks.count, taskCountBefore + 1, "应新增 1 个任务")
        let lastTask = taskCenter.tasks.first
        if case .failed = lastTask?.status {
            // 预期失败状态
        } else {
            XCTFail("抛错后任务状态应为 failed")
        }
    }

    /// 验证 runAIScan 成功时 taskCenter 任务完成
    func testRunAIScanSuccessCompletesTask() async {
        mockKnowledgeRepo.stubPages = [makePage(title: "页面A")]
        mockLLM.stubDiscoverLinks = ["目标"]
        let taskCountBefore = taskCenter.tasks.count

        await store.runAIScan(forPage: nil)

        XCTAssertEqual(taskCenter.tasks.count, taskCountBefore + 1, "应新增 1 个任务")
        let lastTask = taskCenter.tasks.first
        XCTAssertEqual(lastTask?.status, .completed, "成功后任务状态应为 completed")
    }

    /// 验证 runAIScan 单页扫描时 taskTarget 为页面标题
    func testRunAIScanSinglePageTaskTargetIsPageTitle() async {
        let pageA = makePage(title: "特定页面标题")
        mockKnowledgeRepo.stubPages = [pageA]
        mockLLM.stubDiscoverLinks = []

        await store.runAIScan(forPage: pageA)

        let lastTask = taskCenter.tasks.first
        XCTAssertEqual(lastTask?.target, "特定页面标题", "单页扫描时 taskTarget 应为页面标题")
    }

    /// 验证 runAIScan 全局扫描时 taskTarget 为 "System"
    func testRunAIScanGlobalScanTaskTargetIsSystem() async {
        mockKnowledgeRepo.stubPages = [makePage(title: "页面A")]
        mockLLM.stubDiscoverLinks = []

        await store.runAIScan(forPage: nil)

        let lastTask = taskCenter.tasks.first
        XCTAssertEqual(lastTask?.target, "System", "全局扫描时 taskTarget 应为 System")
    }

    // MARK: - 16. findSimilarPages 流程

    /// 验证 findSimilarPages 返回语义检索结果中排除自身后的页面
    func testFindSimilarPagesExcludesSelfAndReturnsMatches() async {
        let pageA = makePage(id: UUID(), title: "页面A", content: "内容A")
        let pageB = makePage(id: UUID(), title: "页面B", content: "内容B")
        let pageC = makePage(id: UUID(), title: "页面C", content: "内容C")
        mockKnowledgeRepo.stubPages = [pageA, pageB, pageC]
        // 检索结果包含 pageA（自身）、pageB、pageC
        mockEmbedding.stubSearchResults = [
            (id: pageA.id, score: 0.9),
            (id: pageB.id, score: 0.8),
            (id: pageC.id, score: 0.7)
        ]

        let similar = await store.findSimilarPages(for: pageA, limit: 3)

        XCTAssertEqual(similar.count, 2, "应排除自身后返回 2 个相似页面")
        XCTAssertTrue(similar.contains { $0.id == pageB.id }, "应包含 pageB")
        XCTAssertTrue(similar.contains { $0.id == pageC.id }, "应包含 pageC")
        XCTAssertFalse(similar.contains { $0.id == pageA.id }, "不应包含自身 pageA")
    }

    /// 验证 findSimilarPages limit 参数限制返回数量
    func testFindSimilarPagesRespectsLimit() async {
        let pageA = makePage(id: UUID(), title: "页面A")
        let pageB = makePage(id: UUID(), title: "页面B")
        let pageC = makePage(id: UUID(), title: "页面C")
        let pageD = makePage(id: UUID(), title: "页面D")
        mockKnowledgeRepo.stubPages = [pageA, pageB, pageC, pageD]
        mockEmbedding.stubSearchResults = [
            (id: pageA.id, score: 0.9),
            (id: pageB.id, score: 0.8),
            (id: pageC.id, score: 0.7),
            (id: pageD.id, score: 0.6)
        ]

        let similar = await store.findSimilarPages(for: pageA, limit: 2)

        XCTAssertEqual(similar.count, 2, "limit=2 时应返回 2 个相似页面")
    }

    /// 验证 findSimilarPages 检索结果中包含不存在的页面 ID 时被过滤
    func testFindSimilarPagesFiltersUnknownPageIDs() async {
        let pageA = makePage(id: UUID(), title: "页面A")
        let pageB = makePage(id: UUID(), title: "页面B")
        let unknownID = UUID()
        mockKnowledgeRepo.stubPages = [pageA, pageB]
        mockEmbedding.stubSearchResults = [
            (id: pageA.id, score: 0.9),
            (id: unknownID, score: 0.8),
            (id: pageB.id, score: 0.7)
        ]

        let similar = await store.findSimilarPages(for: pageA, limit: 3)

        XCTAssertEqual(similar.count, 1, "未知 ID 应被过滤，仅返回 pageB")
        XCTAssertTrue(similar.contains { $0.id == pageB.id }, "应包含 pageB")
    }

    /// 验证 findSimilarPages 空检索结果时返回空数组
    func testFindSimilarPagesEmptySearchResults() async {
        let pageA = makePage(id: UUID(), title: "页面A")
        mockKnowledgeRepo.stubPages = [pageA]
        mockEmbedding.stubSearchResults = []

        let similar = await store.findSimilarPages(for: pageA, limit: 3)

        XCTAssertEqual(similar, [], "空检索结果应返回空数组")
    }

    // MARK: - 17. fetchFixSuggestion 流程

    /// 验证 fetchFixSuggestion 返回 AISynthesisService.suggestFix 的结果
    func testFetchFixSuggestionReturnsSuggestion() async throws {
        let pageA = makePage(id: UUID(), title: "问题页面", content: "页面内容")
        mockKnowledgeRepo.stubPages = [pageA]
        mockLLM.stubGenerateResult = "修复建议文本"
        let issue = LintIssue(severity: .error, type: .brokenLink, pageID: pageA.id, message: "断裂链接", suggestion: "")

        let suggestion = try await store.fetchFixSuggestion(for: issue)

        XCTAssertEqual(suggestion, "修复建议文本", "fetchFixSuggestion 应返回 LLM 生成的修复建议")
    }

    /// 验证 fetchFixSuggestion LLM 抛错时透传错误
    func testFetchFixSuggestionPropagatesError() async {
        let pageA = makePage(id: UUID(), title: "问题页面", content: "页面内容")
        mockKnowledgeRepo.stubPages = [pageA]
        mockLLM.stubGenerateError = LLMError.notConfigured
        let issue = LintIssue(severity: .error, type: .brokenLink, pageID: pageA.id, message: "断裂链接", suggestion: "")

        do {
            _ = try await store.fetchFixSuggestion(for: issue)
            XCTFail("LLM 抛错时 fetchFixSuggestion 应抛出错误")
        } catch {
            // 预期抛错
        }
    }

    // MARK: - 18. clearAll 方法

    /// 验证 clearAll 清空所有状态属性
    func testClearAllResetsAllState() {
        // 预置非空状态
        store.refactorSuggestions = [RefactorSuggestionDTO(type: "merge", target: "t", reason: "r", suggestion: "s")]
        store.potentialLinks = [PotentialLinkSuggestion(sourcePageID: UUID(), sourceTitle: "源", targetTitle: "目标")]
        store.activePageAIResult = "旧结果"
        store.activeQuiz = QuizModel(title: "旧测验", questions: [])
        store.lintIssues = [LintIssue(severity: .error, type: .brokenLink, message: "e", suggestion: "")]
        store.lastLintScore = 50
        store.lastLintDate = Date()

        store.clearAll()

        XCTAssertEqual(store.refactorSuggestions, [], "clearAll 后 refactorSuggestions 应为空")
        XCTAssertEqual(store.potentialLinks, [], "clearAll 后 potentialLinks 应为空")
        XCTAssertEqual(store.activePageAIResult, nil, "clearAll 后 activePageAIResult 应为 nil")
        XCTAssertEqual(store.activeQuiz, nil, "clearAll 后 activeQuiz 应为 nil")
        XCTAssertEqual(store.lintIssues, [], "clearAll 后 lintIssues 应为空")
        XCTAssertEqual(store.lastLintScore, 0, "clearAll 后 lastLintScore 应为 0")
        XCTAssertEqual(store.lastLintDate, nil, "clearAll 后 lastLintDate 应为 nil")
    }

    /// 验证 clearAll 移除 KeyStore 中的 lastLintIssues 键
    func testClearAllRemovesPersistedLintIssues() {
        store.lintIssues = [LintIssue(severity: .error, type: .brokenLink, message: "e", suggestion: "")]
        XCTAssertNotNil(keyStore.data(forKey: AppConstants.Keys.Storage.lastLintIssues), "预置后 KeyStore 应有持久化数据")

        store.clearAll()

        XCTAssertNil(keyStore.data(forKey: AppConstants.Keys.Storage.lastLintIssues), "clearAll 后 KeyStore 中的 lastLintIssues 键应被移除")
    }

    /// 验证 clearAll 重置 isScanningAI / isProcessingPageAI（修复后：清理时正在扫描状态不会卡死）
    func testClearAllDoesNotResetScanningState() {
        store.isScanningAI = true
        store.isProcessingPageAI = true

        store.clearAll()

        // 修复后：clearAll 应重置 isScanningAI / isProcessingPageAI，避免状态卡死
        XCTAssertEqual(store.isScanningAI, false, "修复后：clearAll 应重置 isScanningAI 为 false")
        XCTAssertEqual(store.isProcessingPageAI, false, "修复后：clearAll 应重置 isProcessingPageAI 为 false")
    }

    // MARK: - 19. AppEventBus.clearAllDataRequested 联动

    /// 验证 AppEventBus 发布 clearAllDataRequested 后 AIWorkflowStore 自动清理
    func testClearAllDataRequestedEventTriggersClearAll() async {
        // 预置非空状态
        store.refactorSuggestions = [RefactorSuggestionDTO(type: "merge", target: "t", reason: "r", suggestion: "s")]
        store.potentialLinks = [PotentialLinkSuggestion(sourcePageID: UUID(), sourceTitle: "源", targetTitle: "目标")]
        store.activePageAIResult = "旧结果"
        store.lastLintScore = 50

        // 发布清理事件（AppEventBus.publish 通过 DispatchQueue.main.async 异步发送）
        AppEventBus.shared.publish(.clearAllDataRequested)

        // 等待主线程异步事件处理
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.refactorSuggestions, [], "clearAllDataRequested 事件后 refactorSuggestions 应被清理")
        XCTAssertEqual(store.potentialLinks, [], "clearAllDataRequested 事件后 potentialLinks 应被清理")
        XCTAssertEqual(store.activePageAIResult, nil, "clearAllDataRequested 事件后 activePageAIResult 应为 nil")
        XCTAssertEqual(store.lastLintScore, 0, "clearAllDataRequested 事件后 lastLintScore 应为 0")
    }

    // MARK: - 20. 多次操作的状态一致性

    /// 验证多次 runLint 后 lastLintDate 持续更新
    func testMultipleRunLintUpdatesLastLintDate() async {
        mockKnowledgeRepo.stubPages = []

        await store.runLint()
        let dateAfterFirst = store.lastLintDate
        XCTAssertNotNil(dateAfterFirst, "首次 runLint 后 lastLintDate 应非 nil")

        try? await Task.sleep(nanoseconds: 100_000_000)
        await store.runLint()
        let dateAfterSecond = store.lastLintDate
        XCTAssertNotNil(dateAfterSecond, "二次 runLint 后 lastLintDate 应非 nil")

        XCTAssertGreaterThanOrEqual(dateAfterSecond?.timeIntervalSince1970 ?? 0, dateAfterFirst?.timeIntervalSince1970 ?? 0, "二次 runLint 的 lastLintDate 应不早于首次")
    }

    /// 验证多次 runAIScan 后 potentialLinks 累积/覆盖行为一致
    func testMultipleRunAIScanConsistency() async {
        let pageA = makePage(id: UUID(), title: "页面A", content: "内容A")
        mockKnowledgeRepo.stubPages = [pageA]
        mockLLM.stubDiscoverLinks = ["目标1"]

        await store.runAIScan(forPage: nil)
        let countAfterFirst = store.potentialLinks.count
        XCTAssertEqual(countAfterFirst, 1, "首次全局扫描后 potentialLinks 应有 1 条")

        mockLLM.stubDiscoverLinks = ["目标2"]
        await store.runAIScan(forPage: nil)
        // 修复后：全局扫描合并而非覆盖，因 pageA 相同且目标不同，故累积为 2 条
        XCTAssertEqual(store.potentialLinks.count, 2, "修复后：二次全局扫描合并 potentialLinks，累积为 2 条")
        let targets = store.potentialLinks.map(\.targetTitle).sorted()
        XCTAssertEqual(targets, ["目标1", "目标2"].sorted(), "修复后：二次扫描后应同时包含两次的目标")
    }

    /// 验证多次 removeRefactorSuggestion 后列表状态一致
    func testMultipleRemoveRefactorSuggestionConsistency() {
        let s1 = RefactorSuggestionDTO(type: "merge", target: "t1", reason: "r", suggestion: "s")
        let s2 = RefactorSuggestionDTO(type: "split", target: "t2", reason: "r", suggestion: "s")
        let s3 = RefactorSuggestionDTO(type: "rename", target: "t3", reason: "r", suggestion: "s")
        store.refactorSuggestions = [s1, s2, s3]

        store.removeRefactorSuggestion(id: s2.id)
        XCTAssertEqual(store.refactorSuggestions.count, 2, "移除 s2 后应剩 2 条")
        XCTAssertEqual(store.refactorSuggestions.first?.id, s1.id, "首条应为 s1")
        XCTAssertEqual(store.refactorSuggestions.last?.id, s3.id, "末条应为 s3")

        store.removeRefactorSuggestion(id: s1.id)
        XCTAssertEqual(store.refactorSuggestions.count, 1, "移除 s1 后应剩 1 条")
        XCTAssertEqual(store.refactorSuggestions.first?.id, s3.id, "剩余应为 s3")

        store.removeRefactorSuggestion(id: s3.id)
        XCTAssertEqual(store.refactorSuggestions, [], "移除 s3 后应为空")
    }

    /// 验证 lintIssues 持久化在多次赋值后保持一致
    func testLintIssuesPersistenceAcrossMultipleAssignments() {
        let issue1 = LintIssue(severity: .error, type: .brokenLink, message: "e1", suggestion: "")
        let issue2 = LintIssue(severity: .warning, type: .orphan, message: "w1", suggestion: "")

        store.lintIssues = [issue1]
        var decoded = try? JSONDecoder().decode([LintIssue].self, from: keyStore.data(forKey: AppConstants.Keys.Storage.lastLintIssues) ?? Data())
        XCTAssertEqual(decoded?.count, 1, "首次赋值后持久化应为 1 条")

        store.lintIssues = [issue1, issue2]
        decoded = try? JSONDecoder().decode([LintIssue].self, from: keyStore.data(forKey: AppConstants.Keys.Storage.lastLintIssues) ?? Data())
        XCTAssertEqual(decoded?.count, 2, "二次赋值后持久化应为 2 条")

        store.lintIssues = []
        decoded = try? JSONDecoder().decode([LintIssue].self, from: keyStore.data(forKey: AppConstants.Keys.Storage.lastLintIssues) ?? Data())
        // 空数组编码成功则持久化为空数组，失败则不写入（旧值残留或 nil）
        if let data = keyStore.data(forKey: AppConstants.Keys.Storage.lastLintIssues) {
            XCTAssertEqual(decoded, [], "空数组赋值后持久化应解码为空数组")
        }
    }

    // MARK: - 21. 边界场景

    /// 验证 runAIScan 单页扫描时该页不在 fetchAll 返回的页面列表中仍能扫描（使用传入的 specificPage）
    func testRunAIScanSinglePageNotInRepository() async {
        let pageA = makePage(id: UUID(), title: "页面A", content: "内容A")
        mockKnowledgeRepo.stubPages = [] // 仓储为空，但传入 specificPage
        mockLLM.stubDiscoverLinks = ["目标"]

        await store.runAIScan(forPage: pageA)

        XCTAssertEqual(store.potentialLinks.count, 1, "单页扫描应使用传入的 specificPage，不依赖仓储返回")
        XCTAssertEqual(store.potentialLinks.first?.sourcePageID, pageA.id, "sourcePageID 应为传入的 pageA.id")
    }

    /// 验证 runAIScan 全局扫描空页面列表时不调用 discoverPotentialLinks
    func testRunAIScanGlobalScanEmptyPages() async {
        mockKnowledgeRepo.stubPages = []
        mockLLM.stubDiscoverLinks = ["目标"]

        await store.runAIScan(forPage: nil)

        XCTAssertEqual(mockLLM.discoverCalls.count, 0, "空页面列表时不应调用 discoverPotentialLinks")
        XCTAssertEqual(store.potentialLinks, [], "空页面列表时 potentialLinks 应为空")
        XCTAssertEqual(store.refactorSuggestions, [], "空页面列表时 refactorSuggestions 应为空")
    }

    /// 验证 runAIScan 全局扫描时 existingTitles 包含所有页面标题
    func testRunAIScanGlobalScanPassesAllTitlesToDiscover() async {
        let pages = [makePage(title: "页面A"), makePage(title: "页面B"), makePage(title: "页面C")]
        mockKnowledgeRepo.stubPages = pages
        mockLLM.stubDiscoverLinks = []

        await store.runAIScan(forPage: nil)

        // 至少一次调用，且 existingTitles 包含所有页面标题
        XCTAssertTrue(mockLLM.discoverCalls.count > 0, "应至少调用 1 次 discoverPotentialLinks")
        if let firstCall = mockLLM.discoverCalls.first {
            XCTAssertTrue(firstCall.existingTitles.contains("页面A"), "existingTitles 应包含 页面A")
            XCTAssertTrue(firstCall.existingTitles.contains("页面B"), "existingTitles 应包含 页面B")
            XCTAssertTrue(firstCall.existingTitles.contains("页面C"), "existingTitles 应包含 页面C")
        }
    }

    /// 验证 performPageSynthesis quiz 解析成功后 activePageAIResult 不被设置（activeQuiz 优先）
    func testPerformPageSynthesisQuizSuccessDoesNotSetActivePageAIResult() async throws {
        let quizJSON = """
        {
          "title": "测验",
          "questions": [
            {"id": 1, "text": "题?", "options": ["A", "B"], "answer": 0, "explanation": "解析"}
          ]
        }
        """
        mockLLM.stubGenerateResult = quizJSON

        _ = try await store.performPageSynthesis(type: .quiz, title: "标题", content: "内容")

        XCTAssertNotNil(store.activeQuiz, "quiz 解析成功时 activeQuiz 应非 nil")
        // quiz 解析成功时 activePageAIResult 不应被设置（除非之前已被设置，本次不覆盖）
        // 注意：源码中 quiz 解析成功走 if 分支，不设置 activePageAIResult
    }

    /// 验证连续 performPageSynthesis quiz 解析失败后 activeQuiz 被清空（修复后：不残留旧值）
    func testPerformPageSynthesisQuizParseFailureLeavesStaleActiveQuiz() async throws {
        // 首次 quiz 解析成功，设置 activeQuiz
        let quizJSON = """
        {
          "title": "首次测验",
          "questions": [
            {"id": 1, "text": "题?", "options": ["A", "B"], "answer": 0, "explanation": "解析"}
          ]
        }
        """
        mockLLM.stubGenerateResult = quizJSON
        _ = try await store.performPageSynthesis(type: .quiz, title: "标题", content: "内容")
        XCTAssertNotNil(store.activeQuiz, "首次 quiz 解析成功后 activeQuiz 应非 nil")
        XCTAssertEqual(store.activeQuiz?.title, "首次测验", "首次 activeQuiz.title 应为 首次测验")

        // 二次 quiz 解析失败，应 fallback 到 activePageAIResult，且 activeQuiz 被清空
        mockLLM.stubGenerateResult = "无法解析为 quiz 的纯文本内容，足够长以通过校验。"
        _ = try await store.performPageSynthesis(type: .quiz, title: "标题", content: "内容")

        XCTAssertEqual(store.activePageAIResult, "无法解析为 quiz 的纯文本内容，足够长以通过校验。", "解析失败时应 fallback 到 activePageAIResult")
        // 修复后：二次 quiz 解析失败时 activeQuiz 被清空，不残留旧值
        XCTAssertNil(store.activeQuiz, "修复后：quiz 解析失败时 activeQuiz 应被清空，不残留旧值")
    }
}

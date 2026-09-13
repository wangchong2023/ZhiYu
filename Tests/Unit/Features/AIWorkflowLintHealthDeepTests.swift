//
//  AIWorkflowLintHealthDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AIWorkflowStore Lint/Health 相关深度测试 — 覆盖 runLint/runAIScan（单页+全局+LLM禁用+抛错）、
//            findSimilarPages、fetchFixSuggestion，以发现生产代码潜在 bug 为首要目标。
//  拆分来源：AIWorkflowStoreDeepTests.swift（按 MARK 分段拆分，本文件含 MARK 14-17）。
//

import XCTest
import UFPCore
import Combine
import Dependencies
@testable import ZhiYu

// MARK: - AIWorkflowStore Lint/Health 深度测试（MARK 14-17：runLint / runAIScan / findSimilarPages / fetchFixSuggestion）

@MainActor
final class AIWorkflowLintHealthDeepTests: XCTestCase {

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
}

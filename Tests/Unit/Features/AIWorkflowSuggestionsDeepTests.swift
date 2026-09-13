//
//  AIWorkflowSuggestionsDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AIWorkflowStore 建议相关深度测试 — 覆盖 refactorSuggestions/potentialLinks 增删、
//            removeRefactorSuggestion/removePotentialLink、activePageAIResult/activeQuiz、
//            performPageSynthesis（quiz 解析成功/失败/抛错）、insightStore 属性，
//            以发现生产代码潜在 bug 为首要目标。
//  拆分来源：AIWorkflowStoreDeepTests.swift（按 MARK 分段拆分，本文件含 MARK 8-13）。
//

import XCTest
import UFPCore
import Combine
import Dependencies
@testable import ZhiYu

// MARK: - AIWorkflowStore 建议深度测试（MARK 8-13：refactorSuggestions / removeRefactorSuggestion / potentialLinks / removePotentialLink / activePageAIResult / activeQuiz / insightStore）

@MainActor
final class AIWorkflowSuggestionsDeepTests: XCTestCase {

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
}

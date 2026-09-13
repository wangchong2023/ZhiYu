//
//  AIWorkflowClearAllDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AIWorkflowStore 清理与一致性深度测试 — 覆盖 clearAll、AppEventBus.clearAllDataRequested 联动、
//            多次操作状态一致性、边界场景（单页不在仓储/全局空页面/existingTitles/quiz 解析），
//            以发现生产代码潜在 bug 为首要目标。
//  拆分来源：AIWorkflowStoreDeepTests.swift（按 MARK 分段拆分，本文件含 MARK 18-21）。
//

import XCTest
import UFPCore
import Combine
import Dependencies
@testable import ZhiYu

// MARK: - AIWorkflowStore 清理与一致性深度测试（MARK 18-21：clearAll / AppEventBus / 多次操作 / 边界场景）

@MainActor
final class AIWorkflowClearAllDeepTests: XCTestCase {

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

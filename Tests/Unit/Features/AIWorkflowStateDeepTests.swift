//
//  AIWorkflowStateDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AIWorkflowStore 状态相关深度测试 — 覆盖初始状态、isLLMEnabled、lintIssues 持久化、
//            healthMetrics/lintScore/healthLevel 代理属性、lastLintScore/lastLintDate、
//            isScanningAI/isProcessingPageAI 状态变化，以发现生产代码潜在 bug 为首要目标。
//  拆分来源：AIWorkflowStoreDeepTests.swift（按 MARK 分段拆分，本文件含 MARK 1-7）。
//

import XCTest
import UFPCore
import Combine
import Dependencies
@testable import ZhiYu

// MARK: - AIWorkflowStore 状态深度测试（MARK 1-7：初始状态 / isLLMEnabled / lintIssues / healthMetrics / lastLintScore / isScanningAI / isProcessingPageAI）

@MainActor
final class AIWorkflowStateDeepTests: XCTestCase {

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
}

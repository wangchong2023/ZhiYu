//
//  AIWorkflowStoreTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//
//  系统层级：[L3] 测试层
//  核心职责：验证 AIWorkflowStore 扫描状态、Lint 执行、建议清理与页面级 AI 操作。
//

import Testing
import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class AIWorkflowStoreTests: XCTestCase {
    private var store: AIWorkflowStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = AIWorkflowStore()
    }

    override func tearDown() async throws {
        store = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialIsScanningAIFalse() {
        XCTAssertFalse(store.isScanningAI)
    }

    func testInitialRefactorSuggestionsEmpty() {
        XCTAssertTrue(store.refactorSuggestions.isEmpty)
    }

    func testInitialPotentialLinksEmpty() {
        XCTAssertTrue(store.potentialLinks.isEmpty)
    }

    func testInitialActivePageAIResultNil() {
        XCTAssertNil(store.activePageAIResult)
    }

    func testInitialIsProcessingPageAIFalse() {
        XCTAssertFalse(store.isProcessingPageAI)
    }

    func testInitialActiveQuizNil() {
        XCTAssertNil(store.activeQuiz)
    }

    func testInitialLastLintScoreZero() {
        XCTAssertEqual(store.lastLintScore, 0)
    }

    func testInitialLastLintDateNil() {
        XCTAssertNil(store.lastLintDate)
    }

    // MARK: - clearAll

    func testClearAllResetsState() {
        store.refactorSuggestions = [RefactorSuggestionDTO(type: "merge", target: "A", reason: "r", suggestion: "s")]
        store.potentialLinks = [PotentialLinkSuggestion(sourcePageID: UUID(), sourceTitle: "A", targetTitle: "B")]
        store.activePageAIResult = "结果"
        store.activeQuiz = QuizModel(title: "测试", questions: [])
        store.lintIssues = [LintIssue(severity: .error, message: "m", suggestion: "s")]
        store.lastLintScore = 80
        store.lastLintDate = Date()

        store.clearAll()

        XCTAssertTrue(store.refactorSuggestions.isEmpty)
        XCTAssertTrue(store.potentialLinks.isEmpty)
        XCTAssertNil(store.activePageAIResult)
        XCTAssertNil(store.activeQuiz)
        XCTAssertTrue(store.lintIssues.isEmpty)
        XCTAssertEqual(store.lastLintScore, 0)
        XCTAssertNil(store.lastLintDate)
    }

    // MARK: - removePotentialLink

    func testRemovePotentialLinkRemovesMatchingID() {
        let id = UUID()
        let link = PotentialLinkSuggestion(id: id, sourcePageID: UUID(), sourceTitle: "A", targetTitle: "B")
        store.potentialLinks = [link]

        store.removePotentialLink(id: id)

        XCTAssertTrue(store.potentialLinks.isEmpty)
    }

    func testRemovePotentialLinkKeepsNonMatching() {
        let link = PotentialLinkSuggestion(sourcePageID: UUID(), sourceTitle: "A", targetTitle: "B")
        store.potentialLinks = [link]

        store.removePotentialLink(id: UUID())

        XCTAssertEqual(store.potentialLinks.count, 1)
    }

    // MARK: - removeRefactorSuggestion

    func testRemoveRefactorSuggestionRemovesMatchingID() {
        let suggestion = RefactorSuggestionDTO(type: "merge", target: "A", reason: "r", suggestion: "s")
        store.refactorSuggestions = [suggestion]

        store.removeRefactorSuggestion(id: suggestion.id)

        XCTAssertTrue(store.refactorSuggestions.isEmpty)
    }

    func testRemoveRefactorSuggestionKeepsNonMatching() {
        let suggestion = RefactorSuggestionDTO(type: "merge", target: "A", reason: "r", suggestion: "s")
        store.refactorSuggestions = [suggestion]

        store.removeRefactorSuggestion(id: "nonexistent")

        XCTAssertEqual(store.refactorSuggestions.count, 1)
    }

    // MARK: - runLint

    func testRunLintUpdatesLastLintDate() async {
        await store.runLint()

        XCTAssertNotNil(store.lastLintDate)
    }

    func testRunLintEmptyPagesNoCrash() async {
        await store.runLint()

        XCTAssertTrue(store.lintIssues.isEmpty)
    }

    // MARK: - runAIScan (LLM disabled)

    func testRunAIScanDisabledLLMNoOp() async {
        if let mock = ServiceContainer.shared.resolveOptional((any LLMServiceProtocol).self) as? MockLLMService {
            mock.isEnabled = false
        }

        await store.runAIScan()

        XCTAssertFalse(store.isScanningAI)
    }

    // MARK: - runPageAISummary

    func testRunPageAISummarySetsActiveResult() async throws {
        if let mock = ServiceContainer.shared.resolveOptional((any LLMServiceProtocol).self) as? MockLLMService {
            mock.generateHandler = { _, _ in "摘要内容" }
        }

        let result = try await store.runPageAISummary(content: "测试内容")

        XCTAssertEqual(result, "摘要内容")
        XCTAssertEqual(store.activePageAIResult, "摘要内容")
        XCTAssertFalse(store.isProcessingPageAI)
    }

    // MARK: - runPageAIExtractActions

    func testRunPageAIExtractActionsSetsActiveResult() async throws {
        if let mock = ServiceContainer.shared.resolveOptional((any LLMServiceProtocol).self) as? MockLLMService {
            mock.generateHandler = { _, _ in "行动项列表" }
        }

        let result = try await store.runPageAIExtractActions(content: "测试内容")

        XCTAssertEqual(result, "行动项列表")
        XCTAssertEqual(store.activePageAIResult, "行动项列表")
    }

    // MARK: - runPageAIExpansion

    func testRunPageAIExpansionSetsActiveResult() async throws {
        if let mock = ServiceContainer.shared.resolveOptional((any LLMServiceProtocol).self) as? MockLLMService {
            mock.generateHandler = { _, _ in "扩展内容" }
        }

        let result = try await store.runPageAIExpansion(content: "测试内容")

        XCTAssertEqual(result, "扩展内容")
        XCTAssertEqual(store.activePageAIResult, "扩展内容")
    }

    // MARK: - performPageSynthesis

    func testPerformPageSynthesisSetsActiveResult() async throws {
        if let mock = ServiceContainer.shared.resolveOptional((any LLMServiceProtocol).self) as? MockLLMService {
            mock.generateHandler = { _, _ in "合成结果" }
        }

        let result = try await store.performPageSynthesis(type: .report, title: "测试", content: "内容")

        XCTAssertEqual(result, "合成结果")
        XCTAssertEqual(store.activePageAIResult, "合成结果")
        XCTAssertFalse(store.isProcessingPageAI)
    }
}

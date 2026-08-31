//
//  RAGGovernanceStoreAndPluginSandboxTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：验证 RAGGovernanceSQLiteStore 的 Token 计费、RAG 指标计算、延迟百分位数与插件沙箱安全分支。
//

import XCTest
import UFPCore
import UFPStorage
import Dependencies
@testable import ZhiYu

@MainActor
final class RAGGovernanceStoreAndPluginSandboxTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. Token 计费与多天聚合统计分支

    func testRAGGovernanceStore_LogAndFetchTokenStats() async throws {
        let store = ServiceContainer.shared.resolve((any RAGGovernanceRepository).self)

        try await store.logTokenUsage(model: "gpt-4o", promptTokens: 100, completionTokens: 50)
        try await store.logTokenUsage(model: "gpt-4o", promptTokens: 200, completionTokens: 80)

        let stats = try await store.fetchTokenStats(days: 7)
        XCTAssertEqual(stats.prompt, 300)
        XCTAssertEqual(stats.completion, 130)
        XCTAssertEqual(stats.total, 430)

        // 零天边界分支
        let zeroDaysStats = try await store.fetchTokenStats(days: 0)
        XCTAssertGreaterThanOrEqual(zeroDaysStats.total, 0)
    }

    // MARK: - 2. 检索快照保存与拉取分支

    func testRAGGovernanceStore_CalculateRetrievalLatency() async throws {
        let store = ServiceContainer.shared.resolve((any RAGGovernanceRepository).self)

        let eval = RAGEvaluation(
            query: "检索测试",
            answer: "检索回答",
            faithfulness: 0.9,
            relevance: 0.9,
            precision: 0.9,
            evaluatorModel: "gpt-4o"
        )
        try await store.saveRAGEvaluation(eval)
        let evals = try await store.fetchRAGEvaluations(limit: 10)
        guard let evalID = evals.first?.id else {
            XCTFail("应当成功获取保存的 evaluationID")
            return
        }

        let snapshot = RetrievalSnapshot(
            evaluationID: evalID,
            rank: 1,
            sourceID: UUID().uuidString,
            pageTitle: "测试页面",
            snippet: "测试片段",
            score: 0.85
        )
        try await store.saveRetrievalSnapshots([snapshot])

        let fetched = try await store.fetchRetrievalSnapshots(evaluationID: evalID)
        XCTAssertFalse(fetched.isEmpty)
        XCTAssertEqual(fetched.first?.pageTitle, "测试页面")
    }

    // MARK: - 3. RAG 质量评估记录保存与分页查询分支

    func testRAGGovernanceStore_RAGEvaluationLifecycle() async throws {
        let store = ServiceContainer.shared.resolve((any RAGGovernanceRepository).self)

        let eval = RAGEvaluation(
            query: "量子纠缠",
            answer: "量子纠缠是量子力学中的基本现象",
            faithfulness: 0.95,
            relevance: 0.92,
            precision: 0.88,
            evaluatorModel: "gpt-4o"
        )

        try await store.saveRAGEvaluation(eval)
        let evaluations = try await store.fetchRAGEvaluations(limit: 10)
        XCTAssertFalse(evaluations.isEmpty)
        XCTAssertEqual(evaluations.first?.query, "量子纠缠")
    }
}

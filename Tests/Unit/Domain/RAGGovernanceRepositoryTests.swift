//
//  RAGGovernanceRepositoryTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：测试 RAGGovernanceRepository 中定义的五种重要评估指标与成本结算的数据结构模型的构造及相等性判定。
//

import XCTest
@testable import ZhiYu

final class RAGGovernanceRepositoryTests: XCTestCase {

    /// 测试 TokenStats 构造与 Equatable
    func testTokenStats() {
        // Arrange & Act
        let statsA = TokenStats(prompt: 100, completion: 50, total: 150)
        let statsB = TokenStats(prompt: 100, completion: 50, total: 150)
        let statsC = TokenStats(prompt: 90, completion: 50, total: 140)

        // Assert
        XCTAssertEqual(statsA.prompt, 100)
        XCTAssertEqual(statsA.completion, 50)
        XCTAssertEqual(statsA.total, 150)
        XCTAssertEqual(statsA, statsB, "属性相同应当相等")
        XCTAssertNotEqual(statsA, statsC, "属性不同不应相等")
    }

    /// 测试 DailyAIStat 构造与 Equatable
    func testDailyAIStat() {
        // Arrange & Act
        let statA = DailyAIStat(date: "2026-06-13", tokens: 500, requests: 10)
        let statB = DailyAIStat(date: "2026-06-13", tokens: 500, requests: 10)
        let statC = DailyAIStat(date: "2026-06-12", tokens: 500, requests: 10)

        // Assert
        XCTAssertEqual(statA.date, "2026-06-13")
        XCTAssertEqual(statA.tokens, 500)
        XCTAssertEqual(statA.requests, 10)
        XCTAssertEqual(statA, statB, "属性相同应当相等")
        XCTAssertNotEqual(statA, statC, "日期不同不应相等")
    }

    /// 测试 AverageRAGScores 构造与 Equatable
    func testAverageRAGScores() {
        // Arrange & Act
        let scoresA = AverageRAGScores(
            faithfulness: 0.95,
            relevance: 0.88,
            precision: 0.90,
            hallucinationRate: 0.05,
            citationAccuracy: 0.92,
            answerCorrectness: 0.89,
            contextSufficiency: 0.91
        )
        let scoresB = AverageRAGScores(
            faithfulness: 0.95,
            relevance: 0.88,
            precision: 0.90,
            hallucinationRate: 0.05,
            citationAccuracy: 0.92,
            answerCorrectness: 0.89,
            contextSufficiency: 0.91
        )
        let scoresC = AverageRAGScores(
            faithfulness: 0.80,
            relevance: 0.88,
            precision: 0.90,
            hallucinationRate: 0.05,
            citationAccuracy: 0.92,
            answerCorrectness: 0.89,
            contextSufficiency: 0.91
        )

        // Assert
        XCTAssertEqual(scoresA.faithfulness, 0.95)
        XCTAssertEqual(scoresA.relevance, 0.88)
        XCTAssertEqual(scoresA.precision, 0.90)
        XCTAssertEqual(scoresA.hallucinationRate, 0.05)
        XCTAssertEqual(scoresA.citationAccuracy, 0.92)
        XCTAssertEqual(scoresA.answerCorrectness, 0.89)
        XCTAssertEqual(scoresA.contextSufficiency, 0.91)
        XCTAssertEqual(scoresA, scoresB)
        XCTAssertNotEqual(scoresA, scoresC)

        // 测试带有默认参数（例如答案正确性及上下文充分性）的轻量化构造函数
        let defaultScores = AverageRAGScores(
            faithfulness: 0.9,
            relevance: 0.8,
            precision: 0.85,
            hallucinationRate: 0.1,
            citationAccuracy: 0.85
        )
        XCTAssertEqual(defaultScores.answerCorrectness, 0.0, "答案正确性默认值应当为 0.0")
        XCTAssertEqual(defaultScores.contextSufficiency, 0.0, "上下文充分性默认值应当为 0.0")
    }

    /// 测试 LatencyPercentiles 构造与 Equatable
    func testLatencyPercentiles() {
        // Arrange & Act
        let percentilesA = LatencyPercentiles(p50: 120, p95: 250, p99: 450, sampleCount: 100)
        let percentilesB = LatencyPercentiles(p50: 120, p95: 250, p99: 450, sampleCount: 100)
        let percentilesC = LatencyPercentiles(p50: 120, p95: 250, p99: 500, sampleCount: 100)

        // Assert
        XCTAssertEqual(percentilesA.p50, 120)
        XCTAssertEqual(percentilesA.p95, 250)
        XCTAssertEqual(percentilesA.p99, 450)
        XCTAssertEqual(percentilesA.sampleCount, 100)
        XCTAssertEqual(percentilesA, percentilesB)
        XCTAssertNotEqual(percentilesA, percentilesC)
    }

    /// 测试 TokenEfficiency 构造与 Equatable
    func testTokenEfficiency() {
        // Arrange & Act
        let efficiencyA = TokenEfficiency(totalTokens: 2500, queryCount: 5, avgTokensPerQuery: 500.0, estimatedCostUSD: 0.03)
        let efficiencyB = TokenEfficiency(totalTokens: 2500, queryCount: 5, avgTokensPerQuery: 500.0, estimatedCostUSD: 0.03)
        let efficiencyC = TokenEfficiency(totalTokens: 2500, queryCount: 5, avgTokensPerQuery: 480.0, estimatedCostUSD: 0.03)

        // Assert
        XCTAssertEqual(efficiencyA.totalTokens, 2500)
        XCTAssertEqual(efficiencyA.queryCount, 5)
        XCTAssertEqual(efficiencyA.avgTokensPerQuery, 500.0)
        XCTAssertEqual(efficiencyA.estimatedCostUSD, 0.03)
        XCTAssertEqual(efficiencyA, efficiencyB)
        XCTAssertNotEqual(efficiencyA, efficiencyC)
    }
}

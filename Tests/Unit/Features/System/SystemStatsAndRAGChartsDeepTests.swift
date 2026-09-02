//
//  SystemStatsAndRAGChartsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 SystemStatsView 复杂图表子面板、RAGSatisfactionPanel、
//           RAGCostPanel 与 RAGEvaluationHistoryPanel 评估流水线。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class SystemStatsAndRAGChartsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. RAGSatisfactionPanel 满意度面板状态机测试

    func testRAGSatisfactionPanel_AllScoreTiers() {
        let tiers = [
            (rate: 0.95, up: 19, down: 1),
            (rate: 0.75, up: 15, down: 5),
            (rate: 0.40, up: 4, down: 6),
            (rate: 0.0, up: 0, down: 0)
        ]

        for tier in tiers {
            let host = RAGSatisfactionPanel(
                satisfactionRate: tier.rate,
                satisfactionThumbsUp: tier.up,
                satisfactionThumbsDown: tier.down
            )
            .snapshotEnvironment()
            .renderInWindow()

            XCTAssertNotNil(host.view)
        }
    }

    // MARK: - 2. RAGCostPanel 资源消耗面板测试

    func testRAGCostPanel_DifferentTokenScales() {
        let lowCostEfficiency = TokenEfficiency(
            totalTokens: 15000,
            queryCount: 10,
            avgTokensPerQuery: 1500,
            estimatedCostUSD: 0.03
        )
        let highCostEfficiency = TokenEfficiency(
            totalTokens: 850000,
            queryCount: 200,
            avgTokensPerQuery: 4250,
            estimatedCostUSD: 1.85
        )

        for eff in [lowCostEfficiency, highCostEfficiency] {
            let host = RAGCostPanel(tokenEfficiency: eff)
                .snapshotEnvironment()
                .renderInWindow()

            XCTAssertNotNil(host.view)
        }
    }

    // MARK: - 3. RAGEvaluationHistoryPanel 评估历史列表测试

    func testRAGEvaluationHistoryPanel_EmptyAndFilled() {
        @Dependency(\.ragGovernanceRepository) var governance

        // Empty state
        let emptyHost = RAGEvaluationHistoryPanel(
            recentEvaluations: [],
            governance: governance,
            onReload: {}
        )
        .snapshotEnvironment()
        .renderInWindow()
        XCTAssertNotNil(emptyHost.view)

        // Filled state
        let filledHost = RAGEvaluationHistoryPanel(
            recentEvaluations: [
                RAGEvaluation(
                    id: nil,
                    query: "什么是 LLM Wiki？",
                    answer: "LLM Wiki 是基于卡帕西知识构建范式的知识库",
                    faithfulness: 0.95,
                    relevance: 0.90,
                    precision: 0.88,
                    evaluatorModel: "gpt-4o"
                )
            ],
            governance: governance,
            onReload: {}
        )
        .snapshotEnvironment()
        .renderInWindow()
        XCTAssertNotNil(filledHost.view)
    }
}

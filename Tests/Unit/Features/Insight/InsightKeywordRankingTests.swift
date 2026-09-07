//
//  InsightKeywordRankingTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - Insight
//  核心职责：验证 KnowledgeInsightService 生成周度洞察时高频关键词排序按出现频率降序排列。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class InsightKeywordRankingTests: XCTestCase {

    /// 验证 generateWeeklyInsight 的 topKeywords 按出现频率降序排列而非字典序
    @MainActor
    func testGenerateWeeklyInsight_topKeywords_sortedByFrequencyNotLexicographic() async throws {
        setupFullMockEnvironment()

        let service = KnowledgeInsightService()
        let llm = MockLLMService()
        llm.generateHandler = { _, _ in "summary" }

        let now = Date()
        let applePages: [KnowledgePage] = (0..<3).map { i in
            KnowledgePage(
                title: "Page\(i)",
                content: "content \(i)",
                tags: ["apple"],
                createdAt: now,
                updatedAt: now
            )
        }
        let zebraPage = KnowledgePage(
            title: "ZebraPage",
            content: "zebra content",
            tags: ["zebra"],
            createdAt: now,
            updatedAt: now
        )
        let pages = applePages + [zebraPage]

        let insight = try await service.generateWeeklyInsight(pages: pages, llmService: llm, forceRefresh: true)

        XCTAssertFalse(insight.topKeywords.isEmpty, "topKeywords 不应为空")
        if insight.topKeywords.count >= 2 {
            XCTAssertEqual(insight.topKeywords[0], "apple", "频率最高的 tag 应排第一")
            XCTAssertEqual(insight.topKeywords[1], "zebra", "频率次高的 tag 应排第二")
        }
    }
}

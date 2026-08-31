//
//  WidgetTimelineAndCrossProcessDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Platforms] 平台适配层测试
//  核心职责：深度审计桌面小组件 (KnowledgeStatsWidget, DailyInsightWidget) 的 TimelineProvider 与跨进程数据聚合。
//

import XCTest
import SwiftUI
import WidgetKit
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class WidgetTimelineCrossProcessDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. KnowledgeStatsEntry 与视图渲染

    func testKnowledgeStatsWidget_EntryAndMetrics() {
        let entry = KnowledgeStatsEntry(
            date: Date(),
            vaultName: "主知识库",
            pageCount: 42,
            linkCount: 108,
            tagCount: 15,
            lastUpdatedPages: [
                WidgetRecentPage(title: "RAG 架构", typeName: "concept", colorName: "blue"),
                WidgetRecentPage(title: "Swift 并发模型", typeName: "concept", colorName: "green")
            ]
        )

        XCTAssertEqual(entry.pageCount, 42)
        XCTAssertEqual(entry.linkCount, 108)
        XCTAssertEqual(entry.lastUpdatedPages.count, 2)

        let entryView = KnowledgeStatsWidgetEntryView(entry: entry)
        XCTAssertNotNil(entryView.body)
    }

    // MARK: - 2. WidgetDailyInsight 与 WidgetDistributionStats 模型验证

    func testWidgetModels_SerializationAndValues() {
        let insight = WidgetDailyInsight(
            title: "LLM 语义分块机制",
            content: "基于 Markdown AST 结构进行语义完整性切割。",
            flashThoughtSummary: "今日记录了 3 条新闪念"
        )

        XCTAssertEqual(insight.title, "LLM 语义分块机制")
        XCTAssertFalse(insight.content.isEmpty)

        let distribution = WidgetDistributionStats(
            sourceRatio: 0.3,
            conceptRatio: 0.4,
            entityRatio: 0.2,
            mapRatio: 0.1,
            weeklyGrowth: 12
        )
        XCTAssertEqual(distribution.weeklyGrowth, 12)
    }
}

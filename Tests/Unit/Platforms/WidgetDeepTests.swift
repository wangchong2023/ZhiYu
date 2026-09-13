//
//  WidgetDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：WidgetTimelineAndCrossProcessDeepAuditTests.swift, iOSWidgetsDeepInteractiveTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import WidgetKit
import XCTest

@MainActor
final class WidgetDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

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

    func testKnowledgeStatsEntry_ValidConfiguration() {
        let pages = [
            WidgetRecentPage(title: "分布式系统", typeName: "concept", colorName: "blue"),
            WidgetRecentPage(title: "Swift 6 并发模型", typeName: "entity", colorName: "purple")
        ]
        let entry = KnowledgeStatsEntry(
            date: Date(),
            vaultName: "测试保险库",
            pageCount: 42,
            linkCount: 128,
            tagCount: 15,
            lastUpdatedPages: pages
        )

        XCTAssertEqual(entry.vaultName, "测试保险库")
        XCTAssertEqual(entry.pageCount, 42)
        XCTAssertEqual(entry.linkCount, 128)
        XCTAssertEqual(entry.tagCount, 15)
        XCTAssertEqual(entry.lastUpdatedPages.count, 2)
        XCTAssertEqual(entry.lastUpdatedPages[0].id, "分布式系统")
    }

    func testKnowledgeStatsWidgetEntryView_Rendering() {
        let entry = KnowledgeStatsEntry(
            date: Date(),
            vaultName: "主知识库",
            pageCount: 10,
            linkCount: 25,
            tagCount: 8,
            lastUpdatedPages: [
                WidgetRecentPage(title: "LLM Wiki", typeName: "concept", colorName: "accent")
            ]
        )

        let view = KnowledgeStatsWidgetEntryView(entry: entry)
        let host = UIHostingController(rootView: view)
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "KnowledgeStatsWidgetEntryView 应正常完成视图渲染")
    }

    func testWidgetRepository_FallbackWhenFileNotFound() async {
        let stats = await WidgetRepository.fetchStats()
        XCTAssertGreaterThanOrEqual(stats.pageCount, 0)
        XCTAssertGreaterThanOrEqual(stats.linkCount, 0)
        XCTAssertGreaterThanOrEqual(stats.tagCount, 0)

        let recent = await WidgetRepository.fetchRecentPages(limit: 5)
        XCTAssertTrue(recent.count <= 5)

        let insight = await WidgetRepository.fetchDailyInsight()
        XCTAssertFalse(insight.title.isEmpty)
        XCTAssertFalse(insight.content.isEmpty)

        let dist = await WidgetRepository.fetchDistribution()
        XCTAssertGreaterThanOrEqual(dist.sourceRatio, 0.0)
        XCTAssertGreaterThanOrEqual(dist.conceptRatio, 0.0)
        XCTAssertGreaterThanOrEqual(dist.entityRatio, 0.0)
        XCTAssertGreaterThanOrEqual(dist.mapRatio, 0.0)
    }

    func testWidgetModels_PageRowAndGlobalSettingRow() throws {
        let pageJson = Data("""
        {"title": "知识图谱", "page_type": "concept", "tags": "AI, Graph"}
        """.utf8)
        let pageRow = try JSONDecoder().decode(WidgetPageRow.self, from: pageJson)
        XCTAssertEqual(pageRow.title, "知识图谱")
        XCTAssertEqual(pageRow.pageType, "concept")
        XCTAssertEqual(pageRow.tags, "AI, Graph")

        let settingJson = Data("""
        {"key": "active_vault", "value": "default_vault"}
        """.utf8)
        let settingRow = try JSONDecoder().decode(WidgetGlobalSettingRow.self, from: settingJson)
        XCTAssertEqual(settingRow.key, "active_vault")
        XCTAssertEqual(settingRow.value, "default_vault")

        let snapshotJson = Data("""
        {
            "pageCount": 100,
            "linkCount": 200,
            "tagCount": 30,
            "dailyInsightTitle": "深度洞察",
            "dailyInsightContent": "知识的本质在于连接",
            "flashThoughtSummary": "快思慢想",
            "distribution": {"source": 0.4, "concept": 0.3, "entity": 0.2, "map": 0.1},
            "recentPages": [{"title": "页面A", "typeName": "concept", "colorName": "blue"}]
        }
        """.utf8)
        let snapshot = try JSONDecoder().decode(WidgetStatsSnapshot.self, from: snapshotJson)
        XCTAssertEqual(snapshot.pageCount, 100)
        XCTAssertEqual(snapshot.recentPages.count, 1)
        XCTAssertEqual(snapshot.dailyInsightTitle, "深度洞察")
    }

    func testWidgetSharedConstants_SanityCheck() {
        XCTAssertTrue(WidgetSharedConstants.DeepLink.voice.hasPrefix("zhiyu://"))
        XCTAssertTrue(WidgetSharedConstants.DeepLink.ocr.hasPrefix("zhiyu://"))
        XCTAssertTrue(WidgetSharedConstants.DeepLink.chat.hasPrefix("zhiyu://"))
        XCTAssertTrue(WidgetSharedConstants.DeepLink.search.hasPrefix("zhiyu://"))
        XCTAssertTrue(WidgetSharedConstants.DeepLink.create.hasPrefix("zhiyu://"))
    }

}

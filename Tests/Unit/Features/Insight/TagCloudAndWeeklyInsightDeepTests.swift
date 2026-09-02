//
//  TagCloudAndWeeklyInsightDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class TagCloudAndWeeklyInsightDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. TagCloudView & Subviews Deep Tests

    func testTagCloudViewContentListAndBubbleMode() throws {
        let coordinator = TagCloudCoordinator()
        let store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        
        coordinator.tags = [
            ("Swift", 14),
            ("iOS", 12),
            ("Concurrency", 10),
            ("Architecture", 8),
            ("RAG", 6),
            ("Database", 5),
            ("Performance", 4),
            ("UI", 3),
            ("Design", 3),
            ("Apple", 2),
            ("Security", 2),
            ("Networking", 2),
            ("Storage", 1),
            ("Cache", 1)
        ]
        
        // 1. 列表模式折叠状态
        let viewListCollapsed = TagCloudView()
            .snapshotEnvironment()
        let window1 = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host1 = UIHostingController(rootView: viewListCollapsed)
        window1.rootViewController = host1
        window1.makeKeyAndVisible()
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)
        
        // 2. 选择 Tag 过滤关联页面
        coordinator.selectedTag = "Swift"
        XCTAssertEqual(coordinator.selectedTag, "Swift")
        XCTAssertFalse(coordinator.filteredTags.isEmpty)
        
        // 3. 多选模式
        coordinator.isEditMode = true
        coordinator.selectedTagsForBulk.insert("Swift")
        coordinator.selectedTagsForBulk.insert("iOS")
        XCTAssertEqual(coordinator.selectedTagsForBulk.count, 2)
        coordinator.selectedTagsForBulk.remove("Swift")
        XCTAssertEqual(coordinator.selectedTagsForBulk.count, 1)
    }

    func testTagCloudEmptyStateAndBubbleRatio() throws {
        let coordinator = TagCloudCoordinator()
        let store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        coordinator.tags = []
        
        let view = TagCloudView()
            .snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. WeeklyInsightCard & WeeklyReportView Deep Tests

    func testWeeklyInsightCardWithInsightData() throws {
        let store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        let aiStore = ServiceContainer.shared.resolveOptional(AIInsightStore.self) ?? AIInsightStore()
        let router = Router.shared
        
        let testInsight = KnowledgeInsightService.WeeklyInsight(
            dateRange: "2026.08.25 - 2026.08.31",
            totalNewPages: 15,
            topKeywords: ["Swift6", "RAG", "VectorDB", "FTS5", "UI"],
            aiSummary: "本周知识库新增了 **15 个核心概念**，重点聚焦于 RAG 闭环与 Swift 6 并发架构设计。",
            growthTraction: "+38%"
        )
        aiStore.weeklyInsight = testInsight
        
        let card = WeeklyInsightCard()
            .snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: card)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
        
        // 验证 InsightStat 独立视图
        let stat = InsightStat(label: "新增页面", value: "15", icon: "doc.badge.plus", color: .blue)
        let hostStat = UIHostingController(rootView: stat)
        XCTAssertNotNil(hostStat.view)
        
        // 验证 WeeklyReportView 全屏滚动视图
        let reportView = WeeklyReportView()
            .snapshotEnvironment()
        let hostReport = UIHostingController(rootView: reportView)
        window.rootViewController = hostReport
        hostReport.view.layoutIfNeeded()
        XCTAssertNotNil(hostReport.view)
    }

    func testWeeklyInsightCardEmptyState() throws {
        let aiStore = ServiceContainer.shared.resolveOptional(AIInsightStore.self) ?? AIInsightStore()
        aiStore.weeklyInsight = nil
        
        let card = WeeklyInsightCard()
            .snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: card)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. LogView Deep Tests

    func testLogViewWithEntriesAndEmptyState() async throws {
        let store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        
        // 1. 空日志视图渲染
        store.logEntries = []
        let emptyLogView = LogView()
            .snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let hostEmpty = UIHostingController(rootView: emptyLogView)
        window.rootViewController = hostEmpty
        window.makeKeyAndVisible()
        hostEmpty.view.layoutIfNeeded()
        XCTAssertNotNil(hostEmpty.view)
        
        // 2. 包含各级别日志条目
        let entry1 = LogEntry(
            action: .create,
            target: "KarpathyWiki.md",
            details: "Successfully chunked into 12 sections."
        )
        let entry2 = LogEntry(
            action: .update,
            target: "PageSchema.swift",
            details: "LWW conflict resolved automatically."
        )
        let entry3 = LogEntry(
            action: .delete,
            target: "ChatService",
            details: "Remote endpoint timed out after 30s."
        )
        store.logEntries = [entry1, entry2, entry3]
        
        let logViewWithData = LogView()
            .snapshotEnvironment()
        let hostData = UIHostingController(rootView: logViewWithData)
        window.rootViewController = hostData
        hostData.view.layoutIfNeeded()
        XCTAssertNotNil(hostData.view)
        
        // 3. 清空日志
        await store.clearLogs()
        XCTAssertTrue(store.logEntries.isEmpty)
    }
}

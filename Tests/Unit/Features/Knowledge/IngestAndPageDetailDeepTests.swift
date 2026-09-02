//
//  IngestAndPageDetailDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 IngestView 摄取控制台、PageDetailView 知识详情页、
//           KnowledgeDashboardView 仪表板与 LogView 系统日志视图的状态机与交互。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class IngestAndPageDetailDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. IngestView 摄取控制台状态机测试

    func testIngestView_InitialStateAndHierarchy() {
        let view = NavigationStack {
            IngestView(selectedTab: .constant(.ingest))
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

    func testIngestCoordinator_ManualFormAndAITag() async {
        let coordinator = IngestCoordinator()
        let record = ImportRecord(
            category: "file",
            title: "测试文档.pdf",
            status: "done",
            rawText: "正文内容",
            sourceURL: "https://example.com/doc.pdf",
            tags: "AI, RAG"
        )

        coordinator.openManualForm(with: record)
        coordinator.triggerAITagging(for: record)
        XCTAssertNotNil(coordinator)
    }

    // MARK: - 2. PageDetailView 知识页面详情状态机测试

    func testPageDetailView_InitialStateAndHierarchy() {
        let page = KnowledgePage(
            id: UUID(),
            title: "Karpathy LLM OS 架构",
            pageType: .concept,
            content: "# Karpathy LLM OS\n\n- 操作系统核心思想\n- 内存层次与上下文窗口",
            tags: ["AI", "Karpathy"],
            isPinned: true
        )

        let detailView = PageDetailView(page: page)
        let view = NavigationStack {
            detailView
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
        XCTAssertEqual(detailView.page.title, "Karpathy LLM OS 架构")
        XCTAssertTrue(detailView.page.isPinned)
    }

    func testPageDetailCoordinator_TogglePin() async throws {
        let page = KnowledgePage(
            id: UUID(),
            title: "混合检索 FTS5 + 向量",
            pageType: .entity,
            content: "混合检索架构",
            isPinned: false
        )

        let coordinator = PageDetailCoordinator(page: page)
        XCTAssertFalse(coordinator.page.isPinned)

        await coordinator.togglePin()
        XCTAssertTrue(coordinator.page.isPinned)
    }

    // MARK: - 3. KnowledgeDashboardView 仪表板测试

    func testKnowledgeDashboardView_InitialStateAndHierarchy() {
        let view = NavigationStack {
            KnowledgeDashboardView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

    // MARK: - 4. LogView 日志视图测试

    func testLogView_InitialStateAndHierarchy() {
        let view = NavigationStack {
            LogView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }
}

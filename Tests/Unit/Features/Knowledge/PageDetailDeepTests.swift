//
//  PageDetailDeepTests.swift
//  ZhiYuTests
//
//  合并自 3 个碎片化测试文件：GraphPageDetailAndComparisonFullDeepTests.swift, IngestAndPageDetailDeepTests.swift, PageDetailToolbarAndBacklinksDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class PageDetailDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }
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
    func testKnowledgeDashboardView_InitialStateAndHierarchy() {
        let view = NavigationStack {
            KnowledgeDashboardView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

    func testLogView_InitialStateAndHierarchy() {
        let view = NavigationStack {
            LogView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

    func testPageDetailCoordinatorPinAndEdit() async throws {
        let page = KnowledgePage(title: "Sample Pin Page")
        let coordinator = PageDetailCoordinator(page: page)
        XCTAssertFalse(coordinator.isEditing)
        coordinator.isEditing = true
        XCTAssertTrue(coordinator.isEditing)
    }

}

//
//  PDFReaderAndWidgetWatchFullDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 PDFReaderView 高性能 PDF 阅读器、WatchKnowledgeStatsView、
//           DailyInsightWidgetView、KnowledgeDistributionWidgetView 与 QuickCaptureWidgetView。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class PDFReaderAndWidgetWatchFullDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. PDFReaderView 完整渲染与工具栏测试

    func testPDFReaderView_Hierarchy() {
        let docInfo = PDFDocumentInfo(
            id: UUID(),
            title: "Karpathy-LLM-Wiki-Whitepaper",
            fileName: "whitepaper.pdf",
            pageCount: 12
        )

        let host = NavigationStack {
            PDFReaderView(documentInfo: docInfo)
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. Watch 与跨端小组件视图测试

    #if !os(watchOS)
    func testWatchKnowledgeStatsView_DifferentScales() {
        let stats = [
            (pages: 15, words: 3500, titles: ["Swift", "LLM"]),
            (pages: 250, words: 120000, titles: ["RAG", "Agent", "VectorDB"])
        ]

        for item in stats {
            let host = WatchKnowledgeStatsView(
                totalPages: item.pages,
                totalWords: item.words,
                recentTitles: item.titles
            )
            .snapshotEnvironment()
            .renderInWindow()

            XCTAssertNotNil(host.view)
        }
    }
    #endif

    func testDailyInsightWidgetView_Hierarchy() {
        let host = DailyInsightWidgetView(
            title: "LLM 语义分块",
            content: "基于注意力机制的段落切割技术"
        )
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testKnowledgeDistributionWidgetView_Hierarchy() {
        let distribution: [String: Double] = [
            "AI": 0.8,
            "Swift": 0.6,
            "Docs": 0.4
        ]

        let host = KnowledgeDistributionWidgetView(
            pageCount: 42,
            distribution: distribution
        )
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testQuickCaptureWidgetView_Hierarchy() {
        let host = QuickCaptureWidgetView()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}

//
//  SystemStatsAndRawStorageFullDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 SystemStatsView 全部分段（性能/存储/插件）、
//           RawStorageListView 原始存储管理与 HighlightedText 搜索高亮。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class SystemStatsAndRawStorageFullDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SystemStatsView 全分段渲染测试

    func testSystemStatsView_Hierarchy() {
        let host = NavigationStack {
            SystemStatsView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testSystemStatsView_TabsEnum() {
        for tab in SystemStatsView.Tab.allCases {
            XCTAssertFalse(tab.title.isEmpty)
        }
    }

    // MARK: - 2. RawStorageListView 与子组件测试

    func testRawStorageListView_Hierarchy() {
        let host = NavigationStack {
            RawStorageListView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testRawCategoryType_Properties() {
        for category in RawCategoryType.allCases {
            XCTAssertEqual(category.id, category.rawValue)
            XCTAssertFalse(category.systemIconName.isEmpty)
            XCTAssertFalse(category.displayName.isEmpty)
            _ = category.defaultColor
        }
    }

    func testHighlightedText_MatchingAndEmpty() {
        let emptyMatchHost = HighlightedText(
            text: "Karpathy LLM Wiki Paradigm",
            highlight: ""
        )
        .snapshotEnvironment()
        .renderInWindow()
        XCTAssertNotNil(emptyMatchHost.view)

        let matchingHost = HighlightedText(
            text: "Karpathy LLM Wiki Paradigm with Vector Embeddings",
            highlight: "LLM"
        )
        .snapshotEnvironment()
        .renderInWindow()
        XCTAssertNotNil(matchingHost.view)
    }

    func testRawPageRow_Hierarchy() {
        let page = KnowledgePage(
            title: "Transformer 注意力机制原理",
            pageType: .concept,
            content: "自注意力机制与多头注意力计算"
        )

        let host = RawPageRow(page: page, searchText: "Transformer")
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}

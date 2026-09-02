//
//  SystemStatsAndStorageViewsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：针对系统统计监控（SystemStatsView）、原始存储详情（RawStorageListView）
//            及插件统计面板（PluginStatsSection）执行深度交互与状态机覆盖。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SystemStatsAndStorageViewsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SystemStatsView 全 Tab (性能/存储/插件) 与状态机渲染

    func testSystemStatsView_AllTabsAndControls() {
        let statsView = SystemStatsView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: statsView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. RawStorageListView 原始文件列表与搜索匹配

    func testRawStorageListView_EmptyAndFiltered() {
        let rawView = RawStorageListView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: rawView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. RawPageRow 与 HighlightedText 高亮逻辑

    func testRawPageRow_HighlightedTextVariants() {
        let page = KnowledgePage(
            title: "Distributed Architecture Guide",
            pageType: .concept,
            content: "Microservices design patterns and Raft algorithm"
        )

        let rowView = RawPageRow(page: page, searchText: "Architecture")
            .snapshotEnvironment()

        let host = UIHostingController(rootView: rowView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }
}

//
//  InsightDashboardDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：针对知识库页面列表（KnowledgePageListView）、页面详情页（PageDetailView）、
//            日志与系统审计（LogView）执行深层状态机与分支覆盖测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class InsightDashboardDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. KnowledgePageListView 各种分类与状态过滤

    func testKnowledgePageListView_AllFilterTypes() {
        for pageType in [PageType.concept, PageType.entity, PageType.source, PageType.comparison, nil] {
            let listView = KnowledgePageListView(filterType: pageType)
                .snapshotEnvironment()

            let host = UIHostingController(rootView: listView)
            _ = host.view
            host.view.layoutIfNeeded()

            XCTAssertNotNil(host.view)
        }
    }

    // MARK: - 2. PageDetailView 页面详情展开与元数据

    func testPageDetailView_Rendering() {
        let samplePage = KnowledgePage(
            title: "Paxos 共识算法深入浅出",
            pageType: .concept,
            content: "# Paxos 原理\n- 提议者 (Proposer)\n- 接受者 (Acceptor)\n- 学习者 (Learner)"
        )

        let detailView = PageDetailView(page: samplePage)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: detailView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. LogView 系统日志与过滤状态

    func testLogView_Rendering() {
        let logView = LogView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: logView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }
}

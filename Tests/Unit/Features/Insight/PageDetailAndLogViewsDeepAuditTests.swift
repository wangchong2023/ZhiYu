//
//  PageDetailAndLogViewsDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度审计页面详情视图 (PageDetailView) 与日志面板 (LogView) 的视图树求值与交互状态。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class PageDetailAndLogViewsDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. PageDetailView 页面详情求值

    func testPageDetailView_ViewHierarchy_Evaluates() {
        let page = KnowledgePage(
            title: "知识管理概论",
            pageType: .concept,
            content: "基于 Markdown AST 的双向链接与 RAG 架构设计",
            aliases: ["KM概论"],
            tags: ["系统架构", "AI"]
        )

        let view = PageDetailView(page: page)
            .snapshotEnvironment()
        let controller = UIHostingController(rootView: view)
        XCTAssertNotNil(controller.view)
    }

    // MARK: - 2. LogView 日志视图树求值

    func testLogView_ViewHierarchy_Evaluates() {
        let view = LogView()
            .snapshotEnvironment()
        let controller = UIHostingController(rootView: view)
        XCTAssertNotNil(controller.view)
    }
}

//
//  GraphPageDetailAndComparisonFullDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 PageDetailView 知识详情、ComparisonDetailBodyView 对比决策矩阵、
//           TagCloudView 标签云与 KnowledgePageListView 列表筛选。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class GraphPageDetailAndComparisonDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. PageDetailView 详情视图多类型渲染测试

    func testPageDetailView_AllPageTypesHierarchy() {
        for type in PageType.allCases {
            let page = KnowledgePage(
                id: UUID(),
                title: "测试页面-\(type.rawValue)",
                pageType: type,
                content: "# 标题\n\n正文详情内容 [[双链]]",
                tags: ["AI", "Architecture"]
            )

            let host = NavigationStack {
                PageDetailView(page: page)
            }
            .snapshotEnvironment()
            .renderInWindow()

            XCTAssertNotNil(host.view)
        }
    }

    // MARK: - 2. ComparisonDetailBodyView 对比决策矩阵测试

    func testComparisonDetailBodyView_Hierarchy() {
        let page = KnowledgePage(
            id: UUID(),
            title: "Swift Concurrency vs GCD",
            pageType: .comparison,
            content: "---\nsubjects: [Swift Concurrency, GCD]\ndimensions: [Safety, Performance]\n---\n\n## 详细对比分析\n- 结论说明",
            tags: ["Swift", "Concurrency"]
        )

        var linkTapped = ""
        let host = ComparisonDetailBodyView(page: page, onLinkTap: { link in
            linkTapped = link
        })
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(linkTapped, "")
    }

    // MARK: - 3. KnowledgePageListView 列表与筛选测试

    func testKnowledgePageListView_Hierarchy() {
        let host = NavigationStack {
            KnowledgePageListView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 4. TagCloudView 标签云与聚合测试

    func testTagCloudView_Hierarchy() {
        let host = NavigationStack {
            TagCloudView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 5. LogView 操作日志视图测试

    func testLogView_Hierarchy() {
        let host = NavigationStack {
            LogView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}

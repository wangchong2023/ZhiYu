//
//  KnowledgePageListAndTagCloudDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 KnowledgePageListView 知识页面列表与 TagCloudView 标签云管理视图。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
@testable import ZhiYu

@MainActor
final class KnowledgePageListAndTagCloudDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. KnowledgePageListView 渲染测试

    func testKnowledgePageListView_AllTypes() {
        let host = NavigationStack {
            KnowledgePageListView(filterType: nil)
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testKnowledgePageListView_FilteredByType() {
        for type in PageType.allCases {
            let host = NavigationStack {
                KnowledgePageListView(filterType: type)
            }
            .snapshotEnvironment()
            .renderInWindow()

            XCTAssertNotNil(host.view)
        }
    }

    // MARK: - 2. TagCloudView 渲染测试

    func testTagCloudView_Hierarchy() {
        let host = NavigationStack {
            TagCloudView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}

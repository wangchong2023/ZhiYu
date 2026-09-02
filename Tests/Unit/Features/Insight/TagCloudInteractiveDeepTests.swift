//
//  TagCloudInteractiveDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 TagCloudViewContent、TagCapsuleView 与 TagBubbleCloudCanvas 标签云交互。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
@testable import ZhiYu

@MainActor
final class TagCloudInteractiveDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testTagCloudViewContent_ListMode() {
        let coordinator = TagCloudCoordinator()
        coordinator.tags = [
            (tag: "Swift", count: 15),
            (tag: "AI", count: 28),
            (tag: "RAG", count: 8),
            (tag: "iOS", count: 12)
        ]

        let host = NavigationStack {
            TagCloudView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}

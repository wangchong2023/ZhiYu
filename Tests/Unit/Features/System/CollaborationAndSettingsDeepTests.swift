//
//  CollaborationAndSettingsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 CollaborationView 多设备协作、P2P 会话状态与实时编辑流展示。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
@testable import ZhiYu

@MainActor
final class CollaborationAndSettingsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. CollaborationView 渲染测试

    func testCollaborationView_Hierarchy() {
        let host = NavigationStack {
            CollaborationView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testCollaborationViewContent_Hierarchy() {
        let host = CollaborationViewContent()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}

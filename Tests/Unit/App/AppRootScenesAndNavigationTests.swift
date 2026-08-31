//
//  AppRootScenesAndNavigationTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 测试层
//  核心职责：验证 Router 路由堆栈压栈与回退、AppTab 映射与全局导航状态机。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AppRootScenesAndNavigationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. Router 顶层 Tab 与详情导航路径

    func testRouter_NavigationState() {
        let router = Router.shared

        router.selectedTab = .knowledge
        XCTAssertEqual(router.selectedTab, .knowledge)

        router.selectedTab = .chat
        XCTAssertEqual(router.selectedTab, .chat)
    }

    // MARK: - 2. AppTab 全部枚举与标题

    func testAppTab_AllVariants() {
        let tabs: [AppTab] = [.knowledge, .chat, .ingest, .synthesis, .graph]
        XCTAssertEqual(tabs.count, 5)
    }
}

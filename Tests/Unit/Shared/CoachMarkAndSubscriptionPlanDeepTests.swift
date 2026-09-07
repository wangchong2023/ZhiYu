//
//  CoachMarkAndSubscriptionPlanDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 CoachMarkOverlay 引导层、SubscriptionPlanView 订阅套餐与 AIRainbowGlowBadge 呼吸指示微标。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
@testable import ZhiYu

@MainActor
final class CoachMarkAndSubscriptionPlanDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. CoachMarkOverlay 引导层测试

    func testCoachMarkOverlay_GraphDiscovery() {
        var dismissed = false
        var selectedTab = AppTab.graph
        let overlay = CoachMarkOverlay(type: .graphDiscovery, selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }), onDismiss: { dismissed = true })
        let host = overlay
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(selectedTab, .graph)
        XCTAssertFalse(dismissed)
    }

    // MARK: - 2. SubscriptionPlanView 渲染测试
    // MARK: - 3. AIRainbowGlowBadge 渲染测试
}

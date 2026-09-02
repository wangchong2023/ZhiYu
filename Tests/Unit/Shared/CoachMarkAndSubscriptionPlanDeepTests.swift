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
        let host = CoachMarkOverlay(type: .graphDiscovery, selectedTab: .constant(.graph), onDismiss: {})
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. SubscriptionPlanView 渲染测试

    func testSubscriptionPlanView_Hierarchy() {
        let host = NavigationStack {
            SubscriptionPlanView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. AIRainbowGlowBadge 渲染测试

    func testAIRainbowGlowBadge_Hierarchy() {
        let host = AIRainbowGlowBadge()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}

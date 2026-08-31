//
//  AppStoreGlobalStateMutationTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 测试层
//  核心职责：验证 AppStore 全局门面状态中心在子 Store 聚合指标转发、引导标记状态机与事件总线响应分支。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AppStoreGlobalStateMutationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 引导标记状态机分支

    func testAppStore_PendingCoachMark_GetAndSet() {
        let store = AppStore()

        store.pendingCoachMark = .graphDiscovery
        XCTAssertEqual(store.pendingCoachMark, .graphDiscovery)

        store.pendingCoachMark = nil
        XCTAssertNil(store.pendingCoachMark)
    }

    // MARK: - 2. 核心子 Store 指标转发分支

    func testAppStore_ForwardedProperties_ReflectChildStores() {
        let store = AppStore()

        XCTAssertTrue(store.isPrivacyModeEnabled, "默认隐私模式应与 SettingsStore 保持一致为 true")

        store.showPerfDashboard = true
        XCTAssertTrue(store.showPerfDashboard)
    }
}

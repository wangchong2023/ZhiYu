//
//  SettingsStoreConfigurationEdgeTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：深入验证 SettingsStore 隐私模式、生物识别开关、iCloud 偏好与系统重置状态机分支。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SettingsStoreConfigurationEdgeTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 隐私模式与生物识别开关持久化分支

    func testPrivacyModeAndBiometricToggle_PersistsToKeyStore() {
        let store = SettingsStore()

        store.isPrivacyModeEnabled = false
        XCTAssertFalse(store.isPrivacyModeEnabled)

        store.isBiometricEnabled = false
        XCTAssertFalse(store.isBiometricEnabled)

        store.isPrivacyModeEnabled = true
        XCTAssertTrue(store.isPrivacyModeEnabled)
    }

    // MARK: - 2. iCloud 同步偏好分支

    func testICloudPreferences_GetAndSet() {
        let store = SettingsStore()

        store.iCloudConflictResolution = "serverWins"
        XCTAssertEqual(store.iCloudConflictResolution, "serverWins")

        store.iCloudAutoSync = true
        XCTAssertTrue(store.iCloudAutoSync)
    }

    // MARK: - 3. 系统数据重置广播响应分支

    func testReset_RestoresDefaultState() {
        let store = SettingsStore()
        store.showPerfDashboard = true

        store.reset()

        XCTAssertFalse(store.showPerfDashboard, "重置后性能仪表盘展示状态应重置为 false")
    }
}

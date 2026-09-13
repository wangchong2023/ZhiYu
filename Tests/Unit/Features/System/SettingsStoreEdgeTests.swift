//
//  SettingsStoreEdgeTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 测试层
//  核心职责：测试 SettingsStore 在无 KeyStore 容器降级、自定义 KeyStore 读写持久化及全局重置事件下的边界状态。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class SettingsStoreEdgeTests: XCTestCase {

    override func tearDown() {
        ServiceContainer.shared.reset()
        super.tearDown()
    }

    // MARK: - 1. 无 KeyStore 依赖时的安全降级

    func testDegradationWithoutKeyStore() {
        ServiceContainer.shared.reset()

        let store = SettingsStore()

        XCTAssertTrue(store.isPrivacyModeEnabled)
        XCTAssertTrue(store.isBiometricEnabled)
        XCTAssertFalse(store.showPerfDashboard)
        XCTAssertFalse(store.hasShownGraphCoachMark)
        XCTAssertEqual(store.iCloudConflictResolution, "merge")
        XCTAssertFalse(store.iCloudAutoSync)
        XCTAssertEqual(store.collabUsername, "")

        // 写入时不应崩溃
        store.isPrivacyModeEnabled = false
        store.collabUsername = "Alice"
        store.reset()
    }

    // MARK: - 2. 正常 KeyStore 持久化与同步

    func testKeyStorePersistenceAndEventReset() {
        setupFullMockEnvironment()

        let store = SettingsStore()

        store.isPrivacyModeEnabled = false
        store.isBiometricEnabled = false
        store.hasShownGraphCoachMark = true
        store.iCloudConflictResolution = "overwrite"
        store.iCloudAutoSync = true
        store.collabUsername = "Bob"

        XCTAssertFalse(store.isPrivacyModeEnabled)
        XCTAssertFalse(store.isBiometricEnabled)
        XCTAssertTrue(store.hasShownGraphCoachMark)
        XCTAssertEqual(store.iCloudConflictResolution, "overwrite")
        XCTAssertTrue(store.iCloudAutoSync)
        XCTAssertEqual(store.collabUsername, "Bob")

        // 触发全局重置事件
        AppEventBus.shared.publish(.clearAllDataRequested)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(store.isPrivacyModeEnabled)
        XCTAssertTrue(store.isBiometricEnabled)
        XCTAssertFalse(store.hasShownGraphCoachMark)
        XCTAssertEqual(store.iCloudConflictResolution, "merge")
        XCTAssertFalse(store.iCloudAutoSync)
        XCTAssertEqual(store.collabUsername, "")
    }
}

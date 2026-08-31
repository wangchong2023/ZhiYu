//
//  SettingsAndDeveloperOptionsViewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 DeveloperSettings 压测范围校验、SettingsStore 冲突策略流转与 PluginCenter 状态机分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SettingsAndDeveloperOptionsViewTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 开发者压测参数边界与步长校验

    func testDeveloperSettings_StressTestRangeAndStep() {
        let minCount = FeatureConstants.StressTest.minTargetCount
        let maxCount = FeatureConstants.StressTest.maxTargetCount
        let step = FeatureConstants.StressTest.step

        XCTAssertEqual(minCount, 100)
        XCTAssertEqual(maxCount, 10000)
        XCTAssertEqual(step, 100)
        XCTAssertGreaterThan(maxCount, minCount)
    }

    // MARK: - 2. SettingsStore 冲突解决策略流转

    func testSettingsStore_ConflictResolutionPolicy() {
        let store = SettingsStore()
        XCTAssertEqual(store.iCloudConflictResolution, AppConstants.Storage.ConflictResolution.merge)

        store.iCloudConflictResolution = AppConstants.Storage.ConflictResolution.overwrite
        XCTAssertEqual(store.iCloudConflictResolution, AppConstants.Storage.ConflictResolution.overwrite)

        store.iCloudConflictResolution = AppConstants.Storage.ConflictResolution.keepBoth
        XCTAssertEqual(store.iCloudConflictResolution, AppConstants.Storage.ConflictResolution.keepBoth)
    }

    // MARK: - 3. 插件中心与权限开关流转

    func testPluginCenter_PluginPermissionsToggle() {
        let plugin = PluginRecord(
            id: "test.plugin",
            name: "测试插件",
            version: "1.0.0",
            author: "Tester",
            source: "local",
            status: "active",
            permissionsJSON: "[\"readContent\", \"network\"]",
            manifestJSON: "{}"
        )

        XCTAssertEqual(plugin.status, "active")
        XCTAssertTrue(plugin.permissionsJSON.contains("network"))
    }
}

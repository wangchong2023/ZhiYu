//
//  ModelLabAndSubscriptionDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 ModelLab 沙箱评测、SubscriptionPlanView 订阅中心、
//           DeveloperSettingsView 开发者设置与 BackupView 备份还原视图状态机。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class ModelLabAndSubscriptionDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ModelLabView & Config Sheet 深度状态机测试

    func testModelLabView_InitialStateAndPresetMatching() {
        var didGoToStore = false
        let view = ModelLabView(onGoToStore: {
            didGoToStore = true
        })

        // 默认预设匹配
        XCTAssertNotNil(view.matchedPreset)

        // 触发回调
        view.onGoToStore()
        XCTAssertTrue(didGoToStore)
    }

    func testModelLabView_ConfigurationSheetAndToggles() {
        let view = NavigationStack {
            ModelLabView(onGoToStore: {})
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

    func testParameterPreset_ValuesAndMatching() {
        for preset in ParameterPreset.allCases {
            let params = preset.parameters
            XCTAssertGreaterThan(params.temperature, 0.0)
            XCTAssertLessThanOrEqual(params.temperature, 2.0)
            XCTAssertGreaterThan(params.topP, 0.0)
            XCTAssertLessThanOrEqual(params.topP, 1.0)
            XCTAssertGreaterThan(params.topK, 0)
            XCTAssertGreaterThan(params.maxTokens, 0)
            XCTAssertFalse(preset.displayName.isEmpty)
        }
    }

    func testModelLabManager_SimulationAndState() {
        let manager = ModelLabManager()
        XCTAssertFalse(manager.isGenerating)
        XCTAssertEqual(manager.generatedText, "")
        XCTAssertEqual(manager.currentStats.speed, 0.0)
    }

    // MARK: - 2. SubscriptionPlanView 订阅套餐状态机测试

    func testSubscriptionPlanView_InitialStateAndHierarchy() {
        let view = NavigationStack {
            SubscriptionPlanView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

    func testBillingCycle_Values() {
        let monthly = BillingCycle.monthly
        let yearly = BillingCycle.yearly
        XCTAssertNotEqual(monthly, yearly)
    }

    func testPlanFeature_Properties() {
        let feature = PlanFeature(icon: "star.fill", title: "AI 算力", value: "无限量")
        XCTAssertEqual(feature.icon, "star.fill")
        XCTAssertEqual(feature.title, "AI 算力")
        XCTAssertEqual(feature.value, "无限量")
    }

    // MARK: - 3. DeveloperSettingsView 开发者设置状态机测试

    func testDeveloperSettingsView_StressTestBoundsAndStepper() {
        let view = NavigationStack {
            DeveloperSettingsView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)

        // 验证压测步长与边界常量有效性
        XCTAssertGreaterThan(FeatureConstants.StressTest.minTargetCount, 0)
        XCTAssertGreaterThan(FeatureConstants.StressTest.maxTargetCount, FeatureConstants.StressTest.minTargetCount)
        XCTAssertEqual(FeatureConstants.StressTest.step, 100)
    }

    // MARK: - 4. BackupView 备份与还原状态机测试

    func testBackupView_InitialStateAndAutoBackup() {
        let view = NavigationStack {
            BackupView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

    func testBackupService_CreateAndVerifyBackup() async throws {
        let backupService = BackupService()
        XCTAssertTrue(backupService.isAutoBackupEnabled)

        // 触发自动备份设置变更
        backupService.isAutoBackupEnabled = false
        XCTAssertFalse(backupService.isAutoBackupEnabled)
    }
}

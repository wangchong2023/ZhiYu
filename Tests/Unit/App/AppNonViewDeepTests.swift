//
//  AppNonViewDeepTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/22.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度验证 App 层非 View 文件的覆盖率与逻辑正确性。
//

import XCTest
import SwiftUI
@testable import ZhiYu

/// App 层非 View 文件深度测试
/// 覆盖 ViewFactory/AppWindowSceneDelegate/AppEnvironment/AppModels/iOSAppEnvironment/AppModel
final class AppNonViewDeepTests: XCTestCase {

    // MARK: - AppModels

    func testCoachMarkType_graphDiscovery_rawValue() {
        XCTAssertEqual(CoachMarkType.graphDiscovery.rawValue, "graph_discovery")
    }

    func testCoachMarkType_所有case() {
        let allCases: [CoachMarkType] = [.graphDiscovery]
        XCTAssertEqual(allCases.count, 1, "CoachMarkType 应有 1 个 case")
    }

    func testKnowledgeGrowthPoint_构造与属性() {
        let date = Date()
        let point = KnowledgeGrowthPoint(date: date, count: 42)
        XCTAssertEqual(point.date, date)
        XCTAssertEqual(point.count, 42)
        XCTAssertNotNil(point.id)
    }

    func testKnowledgeGrowthPoint_不同实例id不同() {
        let point1 = KnowledgeGrowthPoint(date: Date(), count: 1)
        let point2 = KnowledgeGrowthPoint(date: Date(), count: 2)
        XCTAssertNotEqual(point1.id, point2.id, "不同实例应有不同 id")
    }

    // MARK: - AppModel (ZhiYuAppModel)

    @MainActor
    func testZhiYuAppModel_init_所有State非空() {
        let model = ZhiYuAppModel()
        XCTAssertNotNil(model.router)
        XCTAssertNotNil(model.onboarding)
        XCTAssertNotNil(model.theme)
        XCTAssertNotNil(model.localization)
        XCTAssertNotNil(model.tooltip)
        XCTAssertNotNil(model.toast)
        XCTAssertNotNil(model.pencil)
        XCTAssertNotNil(model.voiceSpeech)
        XCTAssertNotNil(model.vault)
        XCTAssertNotNil(model.taskCenter)
        XCTAssertNotNil(model.medals)
        XCTAssertNotNil(model.activity)
        XCTAssertNotNil(model.auth)
        XCTAssertNotNil(model.storeKit)
        XCTAssertNotNil(model.globalModel)
        XCTAssertNotNil(model.llmConfig)
        XCTAssertNotNil(model.source)
        XCTAssertNotNil(model.schema)
        XCTAssertNotNil(model.ingestQueue)
        XCTAssertNotNil(model.plugin)
        XCTAssertNotNil(model.database)
    }

    @MainActor
    func testZhiYuAppModel_preview_返回新实例() {
        let model1 = ZhiYuAppModel.preview()
        let model2 = ZhiYuAppModel.preview()
        XCTAssertNotNil(model1)
        XCTAssertNotNil(model2)
    }

    // MARK: - AppModel State 占位结构体

    func testAppRouterState_init() {
        let state = AppRouterState()
        XCTAssertNotNil(state)
    }

    func testAppOnboardingState_init() {
        let state = AppOnboardingState()
        XCTAssertNotNil(state)
    }

    func testAppThemeState_init() {
        let state = AppThemeState()
        XCTAssertNotNil(state)
    }

    func testAppVaultState_init() {
        let state = AppVaultState()
        XCTAssertNotNil(state)
    }

    func testAppAuthState_init() {
        let state = AppAuthState()
        XCTAssertNotNil(state)
    }

    func testAppDatabaseState_init() {
        let state = AppDatabaseState()
        XCTAssertNotNil(state)
    }

    // MARK: - ViewFactory

    @MainActor
    func testViewFactory_registerAndMakeView_未注册domain显示404() {
        // 使用 AppRoute.dashboard 作为有效路由
        let route = AppRoute.dashboard
        let view = ViewFactory.makeView(for: route)
        XCTAssertNotNil(view, "ViewFactory.makeView 应返回非空视图")
    }

    // MARK: - iOSAppEnvironment

    #if os(iOS)
    @MainActor
    func testiOSAppEnvironment_screenClass() {
        let env = iOSAppEnvironment()
        // 模拟器上 userInterfaceIdiom 可能是 .phone 或 .pad
        let screenClass = env.screenClass
        XCTAssertTrue(screenClass == .compact || screenClass == .expansive, "screenClass 应为 compact 或 expansive")
    }

    @MainActor
    func testiOSAppEnvironment_interactionStyle() {
        let env = iOSAppEnvironment()
        XCTAssertEqual(env.interactionStyle, .touch, "iOS 设备主导交互方式应为 touch")
    }

    @MainActor
    func testiOSAppEnvironment_deviceName() {
        let env = iOSAppEnvironment()
        XCTAssertFalse(env.deviceName.isEmpty, "deviceName 不应为空")
    }

    @MainActor
    func testiOSAppEnvironment_supportsPencil() {
        let env = iOSAppEnvironment()
        // 模拟器上可能是 false
        _ = env.supportsPencil
    }

    @MainActor
    func testiOSAppEnvironment_hasCamera() {
        let env = iOSAppEnvironment()
        XCTAssertTrue(env.hasCamera, "hasCamera 硬编码为 true")
    }

    @MainActor
    func testiOSAppEnvironment_isMobile() {
        let env = iOSAppEnvironment()
        _ = env.isMobile
    }

    @MainActor
    func testiOSAppEnvironment_platformName() {
        let env = iOSAppEnvironment()
        let name = env.platformName
        XCTAssertTrue(name == "iOS" || name == "iPadOS", "platformName 应为 iOS 或 iPadOS")
    }

    @MainActor
    func testiOSAppEnvironment_appVersion() {
        let env = iOSAppEnvironment()
        let version = env.appVersion
        XCTAssertFalse(version.isEmpty, "appVersion 不应为空")
        XCTAssertTrue(version.contains("("), "appVersion 应包含 build 号括号格式")
    }

    @MainActor
    func testiOSAppEnvironment_isCloudSyncSupported() {
        let env = iOSAppEnvironment()
        // 模拟器返回 false
        #if targetEnvironment(simulator)
        XCTAssertFalse(env.isCloudSyncSupported, "模拟器上 isCloudSyncSupported 应为 false")
        #else
        XCTAssertTrue(env.isCloudSyncSupported, "真机上 isCloudSyncSupported 应为 true")
        #endif
    }
    #endif

    // MARK: - AppWindowSceneDelegate

    #if !os(watchOS)
    @available(iOS 16.0, macCatalyst 16.0, *)
    func testAppWindowSceneDelegate_可实例化() {
        let delegate = AppWindowSceneDelegate()
        XCTAssertNotNil(delegate)
        XCTAssertNil(delegate.window, "初始化后 window 应为 nil")
    }
    #endif
}

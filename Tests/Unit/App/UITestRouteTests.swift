//
//  UITestRouteTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 UITestRoute 路由注入逻辑。
//
//  注意：`fromLaunchArguments()` 直接读取进程级 `CommandLine.arguments`，
//  无法在单元测试中注入，由 UI 测试（launch argument）覆盖。
//  本测试聚焦 `apply(to:)` 路由应用逻辑。
//

import XCTest
@testable import ZhiYu

@MainActor
final class UITestRouteTests: XCTestCase {

    private var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        router = Router()
    }

    override func tearDown() async throws {
        router = nil
        try await super.tearDown()
    }

    /// 验证 .aiSettings 路由将 router.isShowingAISettingsSheet 设为 true
    func testApplyAISettings_SetsIsShowingAISettingsSheet() {
        XCTAssertFalse(router.isShowingAISettingsSheet)
        UITestRoute.aiSettings.apply(to: router)
        XCTAssertTrue(router.isShowingAISettingsSheet)
    }

    /// 验证 .settings 路由将 router.isShowingSettingsSheet 设为 true
    func testApplySettings_SetsIsShowingSettingsSheet() {
        XCTAssertFalse(router.isShowingSettingsSheet)
        UITestRoute.settings.apply(to: router)
        XCTAssertTrue(router.isShowingSettingsSheet)
    }

    /// 验证 .aiSettings 路由不影响 isShowingSettingsSheet（隔离性）
    func testApplyAISettings_DoesNotAffectSettingsSheet() {
        UITestRoute.aiSettings.apply(to: router)
        XCTAssertFalse(router.isShowingSettingsSheet)
    }

    /// 验证 .settings 路由不影响 isShowingAISettingsSheet（隔离性）
    func testApplySettings_DoesNotAffectAISettingsSheet() {
        UITestRoute.settings.apply(to: router)
        XCTAssertFalse(router.isShowingAISettingsSheet)
    }

    /// 验证 apply 后 dismissSheet 可正确重置状态
    func testApplyThenDismiss_RestoresDefaultState() {
        UITestRoute.aiSettings.apply(to: router)
        UITestRoute.settings.apply(to: router)
        XCTAssertTrue(router.isShowingAISettingsSheet)
        XCTAssertTrue(router.isShowingSettingsSheet)

        router.dismissSheet()
        XCTAssertFalse(router.isShowingAISettingsSheet)
        XCTAssertFalse(router.isShowingSettingsSheet)
    }
}

//
//  ProductionIsolationTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试
//  核心职责：验证空单测宿主身份与测试侧路由参数，不触发真实应用初始化。
//
import Foundation
import Testing
@testable import ZhiYuUnitTestHost

@MainActor
struct ProductionIsolationTests {
    @Test
    func testUnitTestsUseIndependentApplication() {
        #expect(Bundle.main.bundleIdentifier == "top.izhiyu.testing.unit")
    }

    @Test
    func testEmptyArgumentsDoNotOpenTestRoute() {
        #expect(UITestRoute.fromLaunchArguments([]) == nil)
    }

    @Test
    func testUnrelatedArgumentsDoNotOpenTestRoute() {
        #expect(UITestRoute.fromLaunchArguments(["--unrelated"]) == nil)
    }

    @Test
    func testSettingsArgumentSelectsSettings() {
        guard case .settings? = UITestRoute.fromLaunchArguments(["--open-settings"]) else {
            Issue.record("应选择设置路由")
            return
        }
    }

    @Test
    func testAiSettingsTakesPriorityWhenBothArgumentsExist() {
        guard case .aiSettings? = UITestRoute.fromLaunchArguments(["--open-settings", "--open-ai-settings"]) else {
            Issue.record("AI 设置路由应保持既有参数优先级")
            return
        }
    }
}

//
//  BaseUITestCase.swift
//  ZhiYuUITests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] UI 自动化基类
//  核心职责：统一治理 UI 自动化测试环境初始化、动画禁用与元素安全交互机制。
//

import XCTest

@MainActor
open class BaseUITestCase: XCTestCase {

    public var app: XCUIApplication!

    /// 真实后端联调：子类在 setUp 中换取真实 accessToken 后设置此属性，
    /// launch 前会注入 `UITest_InjectAccessToken` 供 AppLauncher 写入 Keychain 恢复会话。
    public var injectedAccessToken: String?

    override open func setUp() async throws {
        try await super.setUp()

        // 避免在非 UI 测试宿主环境跑测初始化崩溃
        if ProcessInfo.processInfo.processName == "ZhiYu" {
            throw XCTSkip("Skipping UI test execution inside Unit Test host process.")
        }

        continueAfterFailure = false
        app = XCUIApplication()
        
        // 传递零动画与状态自愈配置参数
        app.launchArguments = [
            "--uitesting",
            "-UITesting",
            "-ResetUserDefaults",
            "--reset-auth-state"
        ]
        app.launchEnvironment = [
            "UITesting": "true",
            "DISABLE_ANIMATIONS": "true"
        ]
        // 真实后端联调：注入已换取的 accessToken（仅当子类提供时）
        if let token = injectedAccessToken, !token.isEmpty {
            app.launchEnvironment["UITest_InjectAccessToken"] = token
        }
        app.launch()
    }

    override open func tearDown() async throws {
        app = nil
        try await super.tearDown()
    }
}

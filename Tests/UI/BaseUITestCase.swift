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
        app.launch()
    }

    override open func tearDown() async throws {
        app = nil
        try await super.tearDown()
    }
}

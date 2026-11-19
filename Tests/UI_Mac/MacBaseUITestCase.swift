//
//  MacBaseUITestCase.swift
//  ZhiYuMacUITests
//
//  Created by Antigravity on 2026/11/19.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] macOS UI 自动化基类
//  核心职责：统一治理 macOS 原生 App (ZhiYuMac) 的 UI 测试启动、登录态处理与菜单交互。
//  与 iOS 基类 (BaseUITestCase) 的差异：macOS 无 TabBar/Home 键，改用游客模式直达主界面。
//

import XCTest

/// macOS UI 测试基类
///
/// 提供以下核心能力：
///  1. `setUp` — 以游客模式安全启动 ZhiYuMac（跳过登录页，直达主界面）
///  2. `tearDown` — 每个测试用例结束后干净地终止 App 进程
///  3. `waitForMainWindow` — 等待主界面（userProfileMenuButton）出现
///  4. `openSettingsViaMenu` — 通过 ⌘, 快捷键打开 macOS 原生设置窗口
@MainActor
open class MacBaseUITestCase: XCTestCase {

    /// 被测 macOS 应用实例（bundle id 与 ZhiYuMac target 一致）
    var app: XCUIApplication!

    /// 启动参数（游客模式，跳过登录页与新手引导）
    var extraLaunchArguments: [String] { [] }

    override open func setUp() async throws {
        try await super.setUp()

        // 防止在单元测试 target 中运行 UI 测试导致崩溃
        if ProcessInfo.processInfo.processName == "ZhiYuMac" {
            throw XCTSkip("Skipping UI test in Unit Test target to prevent XCUIApplication init crash.")
        }

        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "top.izhiyu.app.mac")

        // 游客模式：--uitesting 会令 ZhiYuApp 将 AuthSession 置为游客，直达主界面无需登录
        app.launchArguments = [
            "--uitesting",
            "-UITesting",
            "-UITest_MockData",
            "--skip-onboarding",
            "-ResetUserDefaults"
        ] + extraLaunchArguments
        app.launchEnvironment = [
            "UITesting": "true",
            "DISABLE_ANIMATIONS": "true"
        ]
        app.launch()
        app.activate()
    }

    override open func tearDown() async throws {
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    /// 等待主窗口出现（macOS 主界面以 userProfileMenuButton 作为稳定锚点）
    @discardableResult
    func waitForMainWindow(timeout: TimeInterval = 20) -> Bool {
        app.buttons["userProfileMenuButton"].waitForExistence(timeout: timeout)
    }

    /// 通过 ⌘, 打开 macOS 原生设置窗口
    @discardableResult
    func openSettingsViaMenu(timeout: TimeInterval = 10) -> Bool {
        app.typeKey(",", modifierFlags: .command)
        return app.windows.firstMatch.waitForExistence(timeout: timeout)
    }

    /// 等待某个窗口标题出现（用于多窗口场景）
    @discardableResult
    func waitForWindow(titled title: String, timeout: TimeInterval = 10) -> Bool {
        app.windows.containing(NSPredicate(format: "title CONTAINS %@", title)).firstMatch
            .waitForExistence(timeout: timeout)
    }
}

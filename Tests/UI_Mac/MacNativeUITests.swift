//
//  MacNativeUITests.swift
//  ZhiYuMacUITests
//
//  Created by Antigravity on 2026/11/19.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] macOS UI 自动化场景测试
//  核心职责：验证 macOS 原生外壳的关键场景——游客模式主界面、⌘, 设置窗口、
//            AISettings 并入 Settings 的 AI Section、菜单栏 ⌘N/⌘P 快捷键。
//  与 iOS 差异：macOS 无 TabBar，改用侧边栏/菜单栏交互。
//

import XCTest

/// macOS 原生 UI 场景测试套件
@MainActor
final class MacNativeUITests: MacBaseUITestCase {

    // MARK: - 1. 主界面（游客模式）

    /// 游客模式启动后应直达主界面（userProfileMenuButton 稳定锚点）
    func testMainWindowAppearsInGuestMode() {
        XCTAssertTrue(waitForMainWindow(), "游客模式启动后应直达主界面（userProfileMenuButton 出现）")
    }

    // MARK: - 2. Settings 打开与 Section 切换

    /// ⌘, 打开 macOS 原生设置窗口，应出现设置窗口
    func testSettingsOpensViaCommandComma() {
        XCTAssertTrue(waitForMainWindow(), "前置：主界面应出现")
        XCTAssertTrue(openSettingsViaMenu(), "⌘, 应打开设置窗口")
    }

    /// 设置窗口应包含 AI Section（AISettings 已并入 Settings，showsDismissButton 隐藏）
    func testAISettingsSectionPresentInSettings() {
        guard waitForMainWindow() else {
            XCTFail("前置：主界面应出现")
            return
        }
        guard openSettingsViaMenu() else {
            XCTFail("前置：⌘, 应打开设置窗口")
            return
        }

        // 设置窗口已打开：点击 AI Section
        // 不硬编码本地化 label，按 label 模糊匹配（覆盖 en="Artificial Intelligence" / zh="人工智能"）
        let aiButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'ai' OR label CONTAINS[c] '人工'")
        ).firstMatch
        XCTAssertTrue(aiButton.waitForExistence(timeout: 10), "设置侧边栏应包含 AI Section")
        aiButton.tap()
    }

    // MARK: - 3. 菜单栏快捷键

    /// ⌘N 新建页面（通过菜单命令触发）
    func testMenuBarNewPageShortcut() {
        guard waitForMainWindow() else {
            XCTFail("前置：主界面应出现")
            return
        }
        app.typeKey("n", modifierFlags: .command)
        // 新建页面通知已派发，无独立窗口；断言 App 仍存活且主界面可交互
        XCTAssertTrue(app.buttons["userProfileMenuButton"].exists, "⌘N 后主界面应保持可交互")
    }

    /// ⌘P 命令面板
    func testMenuBarCommandPaletteShortcut() {
        guard waitForMainWindow() else {
            XCTFail("前置：主界面应出现")
            return
        }
        app.typeKey("p", modifierFlags: .command)
        // 命令面板由 Router.showCommandPalette 驱动，弹出 sheet；以搜索栏 TextField 作为可达锚点
        let paletteSearchField = app.textFields.firstMatch
        XCTAssertTrue(paletteSearchField.waitForExistence(timeout: 10), "⌘P 应弹出命令面板（搜索栏出现）")
    }
}

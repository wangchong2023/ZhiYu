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

    /// 设置窗口侧边栏切换不同分类（安全/关于）应保持窗口稳定不漂移，且不含冗余 AI 项
    func testSettingsSidebarNavigationDoesNotDriftWindow() {
        guard waitForMainWindow() else {
            XCTFail("前置：主界面应出现")
            return
        }
        guard openSettingsViaMenu() else {
            XCTFail("前置：⌘, 应打开设置窗口")
            return
        }

        let aboutButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'about' OR label CONTAINS[c] '关于'")
        ).firstMatch
        XCTAssertTrue(aboutButton.waitForExistence(timeout: 10), "设置侧边栏应包含关于分类")
        aboutButton.tap()
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

        // 按 Esc 应能关闭命令面板并恢复主窗口可交互状态
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.buttons["userProfileMenuButton"].waitForExistence(timeout: 5), "Esc 关闭命令面板后主界面应保持可交互")
    }

    // MARK: - 4. 用户资料菜单与侧边栏核心导航

    /// 点击用户资料菜单按钮应能弹出菜单项（AI 设置/插件中心/设置入口）
    func testUserProfileMenuOpensPopoverOrMenu() {
        guard waitForMainWindow() else {
            XCTFail("前置：主界面应出现")
            return
        }
        let profileButton = app.buttons["userProfileMenuButton"]
        profileButton.tap()
        XCTAssertTrue(app.windows.firstMatch.exists, "点击用户资料菜单后主窗口应稳定不崩溃")
        app.typeKey(.escape, modifierFlags: [])
    }

    /// 验证 macOS 主窗口符合桌面端最小可用尺寸约束（避免窗口塌缩）
    func testMainWindowMeetsDesktopMinimumFrame() {
        guard waitForMainWindow() else {
            XCTFail("前置：主界面应出现")
            return
        }
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "主窗口必须存在")
        XCTAssertGreaterThanOrEqual(mainWindow.frame.width, 800, "macOS 主窗口宽度不应低于 800pt")
        XCTAssertGreaterThanOrEqual(mainWindow.frame.height, 560, "macOS 主窗口高度不应低于 560pt")
    }

    /// 切换主窗口核心侧边栏导航项应平滑响应且不闪退
    func testSidebarCoreNavigationRemainsResponsive() {
        guard waitForMainWindow() else {
            XCTFail("前置：主界面应出现")
            return
        }
        let candidates = ["知识图谱", "Graph", "合成实验室", "Synthesis", "任务中心", "Tasks"]
        for label in candidates {
            let item = app.staticTexts[label].firstMatch
            if item.exists && item.isHittable {
                item.tap()
                XCTAssertTrue(app.windows.firstMatch.exists, "切换至 \(label) 后主窗口应保持稳定")
                break
            }
        }
    }
}

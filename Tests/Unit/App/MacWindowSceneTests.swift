//
//  MacWindowSceneTests.swift
//  ZhiYuTests
//
//  核心职责：验证 UserProfileMenu 辅助窗口登录态守卫逻辑（未登录/非游客不触发 openWindow）。
//
//  说明：ZhiYuTests target 为 iOS platform，不含 Sources/Platforms/macOS/ 目录，
//  openWindow/SettingsLink 为 macOS-only API 无法在 iOS 测试渲染。
//  因此守卫逻辑抽为跨平台纯函数 UserProfileMenu.canOpenAuxWindow(isLoggedIn:isGuest:)，
//  测试直接断言纯函数，避免 macOS-only 渲染依赖。macOS 分支编译正确性由 make mac 保证。
//

import XCTest
@testable import ZhiYuUnitTestHost

@MainActor
final class MacWindowSceneTests: XCTestCase {
    // MARK: - 登录态守卫纯函数断言

    /// 已登录（isLoggedIn=true，isGuest=false）应允许打开辅助窗口
    func testCanOpenAuxWindow_WhenLoggedIn_ReturnsTrue() {
        XCTAssertTrue(UserProfileMenu.canOpenAuxWindow(isLoggedIn: true, isGuest: false))
    }

    /// 游客模式（isLoggedIn=false，isGuest=true）应允许打开辅助窗口
    func testCanOpenAuxWindow_WhenGuest_ReturnsTrue() {
        XCTAssertTrue(UserProfileMenu.canOpenAuxWindow(isLoggedIn: false, isGuest: true))
    }

    /// 同时登录且游客（边界）应允许打开辅助窗口
    func testCanOpenAuxWindow_WhenLoggedInAndGuest_ReturnsTrue() {
        XCTAssertTrue(UserProfileMenu.canOpenAuxWindow(isLoggedIn: true, isGuest: true))
    }

    /// 未登录且非游客（匿名）应禁止打开辅助窗口
    func testCanOpenAuxWindow_WhenNotLoggedInAndNotGuest_ReturnsFalse() {
        XCTAssertFalse(UserProfileMenu.canOpenAuxWindow(isLoggedIn: false, isGuest: false))
    }
}

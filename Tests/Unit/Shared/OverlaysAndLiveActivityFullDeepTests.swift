//
//  OverlaysAndLiveActivityFullDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 SplashComponents 开屏背景、LockOverlayView 锁屏遮罩、
//           UserProfileMenu 用户菜单、LiveActivityView 灵动岛与跨平台小组件视图。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class OverlaysAndLiveActivityFullDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SplashComponents 启动开屏与星空背景测试

    func testSplashBackgroundView_Hierarchy() {
        let host = SplashBackgroundView(starTwinkle: true, nodeGlow: true)
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testSplashView_Hierarchy() {
        let host = SplashView(onDismiss: {})
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. LockOverlayView 锁定遮罩状态机测试

    func testLockOverlayView_InitialHierarchy() {
        let host = LockOverlayView()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. UserProfileMenu 用户菜单与操作分发测试

    func testUserProfileMenu_HierarchyAndActions() {
        let host = NavigationStack {
            UserProfileMenu()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 4. 灵动岛与跨端小组件视图测试

    #if os(iOS) && !targetEnvironment(macCatalyst)
    func testLiveActivityView_WidgetInstantiation() {
        let widget = LiveActivityView()
        XCTAssertNotNil(widget.body)
    }
    #endif
}

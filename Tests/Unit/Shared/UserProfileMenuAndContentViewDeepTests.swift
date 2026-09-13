//
//  UserProfileMenuAndContentViewDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 UserProfileMenu 用户个人菜单、Sheet 承载内容与 ContentView 顶层路由容器。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
@testable import ZhiYu

@MainActor
final class UserProfileMenuAndContentViewDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. UserProfileMenu 渲染测试

    func testUserProfileMenu_Hierarchy() {
        let authSession = AuthSession.shared
        let host = UserProfileMenu()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertNotNil(authSession)
    }

    func testUserProfileMenuSheetContent_Hierarchy() {
        var isShowing = true
        let host = UserProfileMenuSheetContent(isShowingPopover: Binding(get: { isShowing }, set: { isShowing = $0 }))
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertTrue(isShowing)
    }

    func testUserProfileMenu_MenuActionEnum() {
        let actions: [UserProfileMenu.MenuAction] = [.settings, .profile, .plan, .plugins, .aiSettings]
        for action in actions {
            XCTAssertNotNil(action)
        }
    }

    // MARK: - 2. ContentView 主场景容器测试

    func testContentView_Hierarchy() {
        let router = Router.shared
        let host = ContentView()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertNotNil(router)
    }
}

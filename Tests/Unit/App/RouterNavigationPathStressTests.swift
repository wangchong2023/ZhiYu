//
//  RouterNavigationPathStressTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 测试层
//  核心职责：验证 Router 全局路由状态机在侧边栏切换、主 Tab 变更、深度推栈清空与 Sheet 弹窗生命周期分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class RouterNavigationPathStressTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 侧边栏选择自动清空深推栈分支

    func testSidebarSelection_ClearsNavigationPath() {
        let router = Router()
        router.path.append("PageDetail/123")

        XCTAssertFalse(router.path.isEmpty, "初始路径不应为空")

        router.sidebarSelection = .tool(.chat)

        XCTAssertTrue(router.path.isEmpty, "切换侧边栏工具后导航路径必须清空")
        XCTAssertEqual(router.selectedTab, .chat, "选择聊天工具应自动同步主 Tab 为 .chat")
    }

    // MARK: - 2. 主 Tab 切换清空导航分支

    func testSelectedTab_ChangeClearsPath() {
        let router = Router()
        router.path.append("SubPage/456")

        router.selectedTab = .synthesis

        XCTAssertTrue(router.path.isEmpty, "切换主 Tab 后导航路径必须清空")
        XCTAssertEqual(router.selectedTab, .synthesis)
    }

    // MARK: - 3. Sheet 关闭分支

    func testDismissSheet_ResetsFlags() {
        let router = Router()
        router.isShowingSettingsSheet = true
        router.isShowingAISettingsSheet = true

        router.dismissSheet()

        XCTAssertFalse(router.isShowingSettingsSheet)
        XCTAssertFalse(router.isShowingAISettingsSheet)
    }
}

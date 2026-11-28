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
@testable import ZhiYuUnitTestHost

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

    // MARK: - 4. 缺陷 #278 回归：全弹窗重置、SidebarTab 完整性与跨账号切换清理重试队列

    func testDismissSheetAndSourcesHealthCheckSyncTab_WorkCompletely() async {
        let router = Router()
        router.isShowingSettingsSheet = true
        router.isShowingAISettingsSheet = true
        router.isShowingProfileMenu = true
        router.isShowingProfileSheet = true
        router.isShowingPlanSheet = true
        router.isShowingPluginsSheet = true
        router.isShowingAboutSheet = true
        router.showCommandPalette = true

        router.dismissSheet()

        XCTAssertFalse(router.isShowingProfileMenu)
        XCTAssertFalse(router.isShowingProfileSheet)
        XCTAssertFalse(router.isShowingPlanSheet)
        XCTAssertFalse(router.isShowingPluginsSheet)
        XCTAssertFalse(router.isShowingAboutSheet)
        XCTAssertFalse(router.showCommandPalette)

        router.selectedTab = .chat
        router.sidebarSelection = .tool(.sources)
        XCTAssertEqual(router.selectedTab, .knowledge, "切换至信源工具应同步主 Tab 至 .knowledge")

        router.selectedTab = .synthesis
        router.sidebarSelection = .tool(.healthCheck)
        XCTAssertEqual(router.selectedTab, .knowledge, "切换至健康检查应同步主 Tab 至 .knowledge")

        // AuthSession 切换不同用户账号时同步清空遗留待重试支付队列
        let queue = PaymentRetryQueue.shared
        await queue.cancelAllPending()
        AuthSession.shared.update(user: User(id: UUID(), name: "User A", email: "a@example.com"))
        await queue.enqueue(productId: "pro.monthly", receiptData: "receipt_a", transactionId: "tx_switch_user")
        let countAfterEnqueue = await queue.pendingCount
        XCTAssertEqual(countAfterEnqueue, 1)

        AuthSession.shared.update(user: User(id: UUID(), name: "User B", email: "b@example.com"))
        try? await Task.sleep(for: .milliseconds(80))
        let countAfterSwitch = await queue.pendingCount
        XCTAssertEqual(countAfterSwitch, 0, "直接切换另一登录账号时必须清空前序账号遗留支付队列")
        AuthSession.shared.logout()
    }
}

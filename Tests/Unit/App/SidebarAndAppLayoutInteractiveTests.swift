//
//  SidebarAndAppLayoutInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 测试层
//  核心职责：验证侧边栏自适应布局组件、角标格式化、颜色解析、标题容错及深度链接路由状态机。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SidebarAndAppLayoutInteractiveTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SidebarNavigationHelper 核心方法测试

    func testFormatBadgeCount_positiveAndOverflowValues() {
        XCTAssertEqual(SidebarNavigationHelper.formatBadgeCount(1), "1")
        XCTAssertEqual(SidebarNavigationHelper.formatBadgeCount(99), "99")
        XCTAssertEqual(SidebarNavigationHelper.formatBadgeCount(100), "99+")
        XCTAssertEqual(SidebarNavigationHelper.formatBadgeCount(999), "99+")
    }

    func testFormatBadgeCount_zeroOrNegative_returnsNil() {
        XCTAssertNil(SidebarNavigationHelper.formatBadgeCount(0))
        XCTAssertNil(SidebarNavigationHelper.formatBadgeCount(-1))
        XCTAssertNil(SidebarNavigationHelper.formatBadgeCount(-100))
    }

    func testFormatCountText_boundaryCases() {
        XCTAssertEqual(SidebarNavigationHelper.formatCountText(0), "0")
        XCTAssertEqual(SidebarNavigationHelper.formatCountText(-5), "0")
        XCTAssertEqual(SidebarNavigationHelper.formatCountText(12), "12")
        XCTAssertEqual(SidebarNavigationHelper.formatCountText(100), "99+")
    }

    func testResolveIconColor_accentAndNamedColors() {
        XCTAssertEqual(SidebarNavigationHelper.resolveIconColor(colorName: "accent"), .appAccent)
        let blueColor = SidebarNavigationHelper.resolveIconColor(colorName: "blue")
        let purpleColor = SidebarNavigationHelper.resolveIconColor(colorName: "purple")
        XCTAssertNotNil(blueColor)
        XCTAssertNotNil(purpleColor)
    }

    func testResolvePageTitle_emptyOrWhitespace_fallsBackToDefault() {
        XCTAssertEqual(SidebarNavigationHelper.resolvePageTitle(""), L10n.Knowledge.Page.title)
        XCTAssertEqual(SidebarNavigationHelper.resolvePageTitle("   \n\t  "), L10n.Knowledge.Page.title)
        XCTAssertEqual(SidebarNavigationHelper.resolvePageTitle("深度合成架构"), "深度合成架构")
    }

    func testIsCompactScreen_verifiesCorrectness() {
        XCTAssertTrue(SidebarNavigationHelper.isCompactScreen(.compact))
        XCTAssertFalse(SidebarNavigationHelper.isCompactScreen(.regular))
        XCTAssertFalse(SidebarNavigationHelper.isCompactScreen(.expansive))
    }

    // MARK: - 2. 侧边栏行与 Section 视图结构树装载

    func testSidebarIconRow_standardAndFilledBadges() {
        let defaultRow = SidebarIconRow(
            icon: DesignSystem.Icons.dashboard,
            color: .blue,
            title: "控制台",
            badge: 0,
            badgeFilled: false
        )
        XCTAssertNotNil(defaultRow.body)

        let badgeRow = SidebarIconRow(
            icon: DesignSystem.Icons.refresh,
            color: .orange,
            title: "任务中心",
            badge: 105,
            badgeFilled: true
        )
        XCTAssertNotNil(badgeRow.body)
    }

    func testUniverseNavRow_accentAndModelColor() {
        let accentNav = UniverseNavRow(
            icon: DesignSystem.Icons.pageList,
            colorName: "accent",
            title: "所有页面",
            count: 42
        )
        XCTAssertNotNil(accentNav.body)
        XCTAssertEqual(accentNav.iconColor, .appAccent)

        let namedNav = UniverseNavRow(
            icon: DesignSystem.Icons.tag,
            colorName: "green",
            title: "已标记",
            count: 0
        )
        XCTAssertNotNil(namedNav.body)
    }

    func testSidebarTypeRow_allVisibleCases() {
        for type in PageType.allVisibleCases {
            let row = SidebarTypeRow(type: type, count: 5)
            XCTAssertNotNil(row.body)
        }
    }

    func testPageSidebarRow_normalAndEmptyTitles() {
        let normalPage = KnowledgePage(
            id: UUID(),
            title: "量子力学笔记",
            pageType: .concept,
            content: "正文内容",
            createdAt: Date(),
            updatedAt: Date()
        )
        let emptyPage = KnowledgePage(
            id: UUID(),
            title: "   ",
            pageType: .entity,
            content: "空白标题测试",
            createdAt: Date(),
            updatedAt: Date()
        )

        let host = PageSidebarHost(normalPage: normalPage, emptyPage: emptyPage)
        XCTAssertNotNil(host.body)
    }

    // MARK: - 3. DeepLink 消费状态机测试

    func testConsumeDeepLink_openPage() {
        let testID = UUID()
        let router = Router.shared
        router.path = NavigationPath()
        let service = DeepLinkService()
        service.pendingDeepLink = .openPage(id: testID)

        let popped = service.consumeDeepLink()
        if case .openPage(let id) = popped {
            XCTAssertEqual(id, testID)
        } else {
            XCTFail("预期消费 .openPage 深度链接")
        }
        XCTAssertNil(service.pendingDeepLink)

        router.navigateToPage(id: testID)
        XCTAssertEqual(router.path.count, 1)
    }

    func testConsumeDeepLink_searchAndTools() {
        let service = DeepLinkService()
        let router = Router.shared

        service.pendingDeepLink = .search("知识切片")
        if case .search(let query) = service.consumeDeepLink() {
            XCTAssertEqual(query, "知识切片")
            router.navigateToTool(.search)
            XCTAssertEqual(router.sidebarSelection, .tool(.search))
        } else {
            XCTFail("预期解析出 .search 深度链接")
        }

        service.pendingDeepLink = .chat
        if case .chat = service.consumeDeepLink() {
            router.navigateToTool(.chat)
            XCTAssertEqual(router.sidebarSelection, .tool(.chat))
        } else {
            XCTFail("预期解析出 .chat 深度链接")
        }
    }
}

// MARK: - Test Support View

private struct PageSidebarHost: View {
    let normalPage: KnowledgePage
    let emptyPage: KnowledgePage
    @Namespace private var heroNamespace

    var body: some View {
        VStack {
            PageSidebarRow(page: normalPage, heroNamespace: heroNamespace)
            PageSidebarRow(page: emptyPage, heroNamespace: heroNamespace)
        }
    }
}

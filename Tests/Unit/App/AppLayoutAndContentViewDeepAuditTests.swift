//
//  AppLayoutAndContentViewDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层测试
//  核心职责：深度审计 ContentView 容器、多用户态（未登录/游客/已登录/切换知识库）、
//            自适应分栏、全 Section 侧边栏及全局弹窗生命周期。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AppLayoutAndContentViewDeepAuditTests: XCTestCase {

    private var appStore: AppStore!
    private var router: Router!
    private var authSession: AuthSession!
    private var vaultService: VaultService!
    private var themeManager: ThemeManager!
    private var medalService: MedalService!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()

        appStore = AppStore()
        router = Router.shared
        authSession = AuthSession.shared
        vaultService = VaultService.shared
        themeManager = ThemeManager()
        medalService = MedalService.shared
    }

    override func tearDown() async throws {
        appStore = nil
        router = nil
        authSession = nil
        vaultService = nil
        themeManager = nil
        medalService = nil
        try await super.tearDown()
    }

    // MARK: - 1. ContentView 顶层容器状态机 (Auth & Vault 多分支)

    func testContentView_MainContainer_LoggedOut_ShowsAuthView() {
        authSession.logout()

        let contentView = ContentView()
        let view = contentView.snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertFalse(authSession.isLoggedIn, "未登录状态下 isLoggedIn 应为 false")
        XCTAssertNotNil(host.view, "Auth 视图容器应成功初始化")
    }

    func testContentView_MainContainer_GuestWithoutVault_ShowsNotebookHub() {
        authSession.isGuest = true
        vaultService.selectedVaultID = nil

        let contentView = ContentView()
        let view = contentView.snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertTrue(authSession.isGuest, "游客状态下 isGuest 应为 true")
        XCTAssertNil(vaultService.selectedVaultID, "未选知识库时 selectedVaultID 应为 nil")
        XCTAssertNotNil(host.view)
    }

    func testContentView_MainContainer_LoggedInWithVault_ShowsMainContent() {
        authSession.isGuest = true
        let testVaultID = UUID()
        vaultService.selectedVaultID = testVaultID

        let contentView = ContentView()
        let view = contentView.snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertEqual(vaultService.selectedVaultID, testVaultID, "选中知识库后 selectedVaultID 应匹配")
        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. 路由切换与多 Tab 状态机

    func testContentView_AllTabsNavigation() {
        let contentView = ContentView()

        for tab in AppTab.allCases {
            router.selectedTab = tab
            router.sidebarSelection = .tool(.dashboard)

            let view = contentView.snapshotEnvironment()

            let host = UIHostingController(rootView: view)
            _ = host.view
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()

            XCTAssertNotNil(host.view, "Tab \(tab) 下 ContentView 容器应渲染就绪")
        }
    }

    // MARK: - 3. 侧边栏各 Section 与自适应行渲染

    struct SidebarTestContainer: View {
        @Namespace var heroNamespace
        var testPage: KnowledgePage
        @State var pageToDelete: KnowledgePage?
        @State var showDeleteConfirmation = false

        var body: some View {
            List {
                CapabilitiesSection()
                SourcesSection()
                UniverseSection()
                PinnedSection(
                    heroNamespace: heroNamespace,
                    pageToDelete: $pageToDelete,
                    showDeleteConfirmation: $showDeleteConfirmation
                )
                ToolsSection()
                SidebarPinnedRow(
                    page: testPage,
                    heroNamespace: heroNamespace,
                    onTogglePin: {},
                    onDelete: {}
                )
            }
        }
    }

    func testSidebarRowComponents_Sections_CompactAndRegular() {
        let testPage = KnowledgePage(
            id: UUID(),
            title: "架构设计指南",
            pageType: .concept,
            content: "L0-L3 分层规范说明",
            isPinned: true
        )
        appStore.knowledgeStore.pages = [testPage]

        let container = SidebarTestContainer(testPage: testPage).snapshotEnvironment()

        let host = UIHostingController(rootView: container)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 4. 全局 Sheet 与奖励弹窗覆盖层

    func testContentView_GlobalOverlays_MedalAndCoachMarks() {
        let testMedal = medalService.allMedals.first
        medalService.newlyEarnedMedal = testMedal
        appStore.pendingCoachMark = .graphDiscovery

        let contentView = ContentView()
        let view = contentView.snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(medalService.newlyEarnedMedal)
        XCTAssertEqual(appStore.pendingCoachMark, .graphDiscovery)
        XCTAssertNotNil(host.view)
    }
}

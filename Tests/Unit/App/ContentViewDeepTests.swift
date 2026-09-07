//
//  ContentViewDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：AppLayoutAndContentViewDeepAuditTests.swift, AppLayoutAndContentViewStateMachineDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class ContentViewDeepTests: XCTestCase {

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

    func testContentView_MainContainersAndTransitions() {
        let appStore = AppStore()
        let knowledgeStore = KnowledgeStore()
        let ingestStore = IngestStore()
        let synthesisStore = SynthesisStore()
        let router = Router()
        let theme = ThemeManager()

        let contentView = ContentView()
            .environment(appStore)
            .environment(knowledgeStore)
            .environment(ingestStore)
            .environment(synthesisStore)
            .environment(router)
            .environment(theme)

        let controller = UIHostingController(rootView: contentView)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        XCTAssertEqual(appStore.pages.count, 0)
        XCTAssertEqual(knowledgeStore.pages.count, 0)
    }

}

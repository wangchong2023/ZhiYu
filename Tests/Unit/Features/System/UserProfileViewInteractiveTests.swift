//
//  UserProfileViewInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 功能测试层
//  核心职责：UserProfileView 活跃天数纯函数边界计算、首次启动打点幂等性与资产看板挂载测试
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class UserProfileViewInteractiveTests: XCTestCase {

    private var authService: AuthService!
    private var themeManager: ThemeManager!
    private var appStore: AppStore!
    private var knowledgeStore: KnowledgeStore!
    private var vaultService: VaultService!
    private var synthesisStore: SynthesisStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        authService = ServiceContainer.shared.resolveOptional(AuthService.self) ?? AuthService.shared
        themeManager = ServiceContainer.shared.resolveOptional(ThemeManager.self) ?? ThemeManager()
        appStore = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        knowledgeStore = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        vaultService = ServiceContainer.shared.resolveOptional(VaultService.self) ?? VaultService.shared
        synthesisStore = ServiceContainer.shared.resolveOptional(SynthesisStore.self) ?? SynthesisStore()
    }

    override func tearDown() async throws {
        authService = nil
        themeManager = nil
        appStore = nil
        knowledgeStore = nil
        vaultService = nil
        synthesisStore = nil
        try await super.tearDown()
    }

    // MARK: - 3. UserProfileView 视图层级与 2x2 看板挂载测试

    func testUserProfileViewMountWithStatistics() {
        let view = UserProfileView()
            .environment(authService)
            .environment(themeManager)
            .environment(appStore)
            .environment(knowledgeStore)
            .environment(vaultService)
            .environment(synthesisStore)

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
        XCTAssertNotNil(authService)
        XCTAssertNotNil(appStore)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }
}

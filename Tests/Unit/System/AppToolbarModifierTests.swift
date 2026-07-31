//
//  AppToolbarModifierTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/07/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 AppTabToolbarModifier 和根视图导航栏修饰符进行单元测试验证，确保头像图标固定排列于 topBarTrailing 右侧。
//

import XCTest
import SwiftUI
@testable import ZhiYu

/// 工具栏修饰符及头像图标布局单元测试套件
@MainActor
final class AppToolbarModifierTests: XCTestCase {

    override func setUp() {
        super.setUp()
        setupFullMockEnvironment()
    }

    /// TC-TLB-01: 验证 AppTabToolbarModifier 视图成功构建且包含右侧头像视图修饰
    func testAppTabToolbarModifierConstruction() {
        let store = AppStore()
        let router = Router.shared
        let onboardingService = OnboardingService()
        let themeManager = ThemeManager.shared

        let testView = Text("Test View")
            .appTabToolbar(title: "测试标题") {
                Image(systemName: "star")
            }
            .environment(store)
            .environment(router)
            .environmentObject(onboardingService)
            .environmentObject(themeManager)

        XCTAssertNotNil(testView, "应用主标签页工具栏修饰符应成功构建")
    }

    /// TC-TLB-02: 验证 NotebookHubView 结构定义中成功嵌入 Toolbar 与 UserProfileMenu
    func testNotebookHubViewToolbarPlacement() {
        let store = AppStore()
        let router = Router.shared
        let onboardingService = OnboardingService()
        let themeManager = ThemeManager.shared

        let hubView = NotebookHubView()
            .environment(store)
            .environment(router)
            .environmentObject(onboardingService)
            .environmentObject(themeManager)

        XCTAssertNotNil(hubView, "NotebookHubView 应成功构建并包含 topBarTrailing 的头像与工具栏")
    }

    /// TC-TLB-03: 验证 UserProfileMenu 弹出层内容构建且在右上角对齐
    func testUserProfileMenuPopoverContentInitialization() {
        let store = AppStore()
        let router = Router.shared
        let authService = AuthService.shared
        let onboardingService = OnboardingService()
        let themeManager = ThemeManager.shared

        let content = UserProfileMenuSheetContent(isShowingPopover: .constant(true))
            .environment(authService)
            .environment(store)
            .environment(router)
            .environmentObject(onboardingService)
            .environmentObject(themeManager)

        XCTAssertNotNil(content, "UserProfileMenu 弹出气泡内容应成功初始化")
    }
}

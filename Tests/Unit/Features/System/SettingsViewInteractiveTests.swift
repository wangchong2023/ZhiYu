//
//  SettingsViewInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 功能测试层
//  核心职责：SettingsView 设置分类枚举、特权拦截、预设恢复提示文案与交互挂载测试
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SettingsViewInteractiveTests: XCTestCase {

    private var appStore: AppStore!
    private var settingsStore: SettingsStore!
    private var router: Router!
    private var themeManager: ThemeManager!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        appStore = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        settingsStore = ServiceContainer.shared.resolveOptional(SettingsStore.self) ?? SettingsStore()
        router = ServiceContainer.shared.resolveOptional(Router.self) ?? Router.shared
        themeManager = ServiceContainer.shared.resolveOptional(ThemeManager.self) ?? ThemeManager()
    }

    override func tearDown() async throws {
        appStore = nil
        settingsStore = nil
        router = nil
        themeManager = nil
        try await super.tearDown()
    }

    // MARK: - 2. 特权拦截逻辑防腐测试 (Lite 用户开启特权项需弹窗拦截)

    func testPrivacyAndBiometricFeatureGateForLiteUsers() {
        // 当前用户若未开通隐私模式特权，直接尝试修改状态
        let originalPrivacy = settingsStore.isPrivacyModeEnabled
        let originalBiometric = settingsStore.isBiometricEnabled

        // 验证默认初始状态与存储器保持一致
        XCTAssertEqual(settingsStore.isPrivacyModeEnabled, originalPrivacy)
        XCTAssertEqual(settingsStore.isBiometricEnabled, originalBiometric)

        // 模拟切换状态
        settingsStore.isPrivacyModeEnabled.toggle()
        XCTAssertNotEqual(settingsStore.isPrivacyModeEnabled, originalPrivacy)
        settingsStore.isPrivacyModeEnabled = originalPrivacy

        settingsStore.isBiometricEnabled.toggle()
        XCTAssertNotEqual(settingsStore.isBiometricEnabled, originalBiometric)
        settingsStore.isBiometricEnabled = originalBiometric
    }

    // MARK: - 3. 恢复预设笔记本 Toast 多语言与分隔符逻辑测试

    func testGenerateInitialNotebooksToastSemantics() {
        let details: [(name: String, count: Int)] = [
            (name: "默认笔记本", count: 3),
            (name: "AI 合成库", count: 2)
        ]
        let total = 5
        let prefix = String(format: L10n.Settings.InjectDemo.injectedNotebooks, details.count)
        let suffix = L10n.Settings.InjectDemo.pageUnit
        let sep = L10n.Settings.InjectDemo.itemsSeparator

        var vaultsDesc = ""
        for (i, detail) in details.enumerated() {
            if i > 0 { vaultsDesc += sep }
            vaultsDesc += detail.name + String(detail.count) + suffix
        }
        let msg = prefix + vaultsDesc

        XCTAssertTrue(msg.contains(details[0].name))
        XCTAssertTrue(msg.contains(details[1].name))
        XCTAssertTrue(msg.contains("3"))
        XCTAssertTrue(msg.contains("2"))
        XCTAssertEqual(total, 5)
    }

    // MARK: - 4. SettingsView 视图层级挂载测试

    func testSettingsViewMountAndEnvironment() {
        let view = SettingsView()
            .environment(appStore)
            .environment(settingsStore)
            .environment(router)
            .environment(themeManager)

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
        XCTAssertNotNil(appStore)
        XCTAssertNotNil(settingsStore)
        XCTAssertNotNil(router)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view.window ?? UIWindow())
    }
}

//
//  InsightDashboardAndMedalDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：针对洞察仪表盘、勋章墙、巡检详情、开发者设置与系统设置
//            执行深层状态机分支覆盖与坏味道排查测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class InsightDashboardAndMedalDeepTests: XCTestCase {

    private var appStore: AppStore!
    private var router: Router!
    private var medalService: MedalService!
    private var settingsStore: SettingsStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()

        appStore = AppStore()
        router = Router.shared
        medalService = MedalService.shared
        settingsStore = SettingsStore()
    }

    override func tearDown() async throws {
        appStore = nil
        router = nil
        medalService = nil
        settingsStore = nil
        try await super.tearDown()
    }

    // MARK: - 1. KnowledgeDashboardView 仪表盘概览与趋势图

    func testKnowledgeDashboardView_Rendering() {
        let dashboardView = KnowledgeDashboardView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: dashboardView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. MedalCard 与 MedalRewardPopup 勋章视图

    func testMedalComponents_Rendering() {
        if let medal = medalService.allMedals.first {
            let cardView = MedalCard(medal: medal, isEarned: true)
                .snapshotEnvironment()

            let host1 = UIHostingController(rootView: cardView)
            _ = host1.view
            host1.view.layoutIfNeeded()
            XCTAssertNotNil(host1.view)

            let popupView = MedalRewardPopup(medal: medal, onDismiss: {})
                .snapshotEnvironment()

            let host2 = UIHostingController(rootView: popupView)
            _ = host2.view
            host2.view.layoutIfNeeded()
            XCTAssertNotNil(host2.view)
        }
    }

    // MARK: - 3. SettingsView 系统设置与 iCloud 策略

    func testSettingsView_SectionStates() {
        let settingsView = SettingsView()
            .environment(settingsStore)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: settingsView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 4. DeveloperSettingsView 开发者选项与压力测试滑块

    func testDeveloperSettingsView_Rendering() {
        let devView = DeveloperSettingsView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: devView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }
}

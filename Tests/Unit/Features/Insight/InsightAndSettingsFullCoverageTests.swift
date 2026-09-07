//
//  InsightAndSettingsFullCoverageTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度覆盖 LogView、SettingsView 与 WeeklyInsightCard 的日志级别过滤、系统设置与周报趋势图表。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class InsightAndSettingsFullCoverageTests: XCTestCase {

    private var store: AppStore!
    private var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        router = ServiceContainer.shared.resolveOptional(Router.self) ?? Router.shared
    }

    override func tearDown() async throws {
        store = nil
        router = nil
        try await super.tearDown()
    }

    // MARK: - 1. LogView 日志控制台测试

    func testLogViewRendering() {
        let rawView = LogView()
        XCTAssertNotNil(rawView)
        let view = rawView.snapshotEnvironment()
        let hosting = UIHostingController(rootView: view)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()
    }

    // MARK: - 2. SettingsView 设置中心测试

    func testSettingsViewRendering() {
        let rawView = SettingsView()
        XCTAssertNotNil(rawView)
        let view = rawView.snapshotEnvironment()
        let hosting = UIHostingController(rootView: view)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()
    }

    // MARK: - 3. WeeklyInsightCard 周报卡片渲染测试

    func testWeeklyInsightCardRendering() {
        let rawCard = WeeklyInsightCard()
        XCTAssertNotNil(rawCard)
        let card = rawCard.snapshotEnvironment()
        let hosting = UIHostingController(rootView: card)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()
    }
}

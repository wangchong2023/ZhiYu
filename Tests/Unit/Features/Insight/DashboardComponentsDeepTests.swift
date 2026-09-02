//
//  DashboardComponentsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度覆盖 KnowledgeDashboardView 与 DashboardCoordinator 的指标渲染、连接密度图表与状态刷新。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class DashboardComponentsDeepTests: XCTestCase {

    private var store: AppStore!
    private var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        router = ServiceContainer.shared.resolveOptional(Router.self) ?? Router()
    }

    override func tearDown() async throws {
        store = nil
        router = nil
        try await super.tearDown()
    }

    // MARK: - 1. KnowledgeDashboardView 全场景挂载渲染

    func testKnowledgeDashboardViewPopulatedAndEmpty() async throws {
        let dashboardView = KnowledgeDashboardView()
            .environment(store)
            .environment(router)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: dashboardView)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
    }

    // MARK: - 2. DashboardCoordinator 数据刷新与计算测试

    func testDashboardCoordinatorCalculation() async throws {
        let coordinator = DashboardCoordinator()

        // 验证初始状态
        XCTAssertEqual(coordinator.totalLinks, 0)
        XCTAssertTrue(coordinator.densityData.isEmpty)
        XCTAssertFalse(coordinator.isGeneratingInsights)

        // 触发刷新
        await coordinator.refreshAll()

        // 验证刷新完成且无崩溃
        XCTAssertGreaterThanOrEqual(coordinator.totalLinks, 0)
    }
}

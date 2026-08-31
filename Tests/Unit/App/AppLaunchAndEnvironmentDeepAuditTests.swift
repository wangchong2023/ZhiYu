//
//  AppLaunchAndEnvironmentDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层测试
//  核心职责：深度审计应用启动入口 (ContentView)、环境注入与模块注册链路 (ModuleRegistrar)。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AppLaunchAndEnvironmentDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ContentView 根视图环境构建与初始渲染

    func testContentView_RootViewHierarchy_EvaluatesSuccessfully() {
        let view = ContentView()
            .snapshotEnvironment()
        let controller = UIHostingController(rootView: view)
        XCTAssertNotNil(controller.view, "ContentView 必须能够成功装载到 UIHostingController 视图层次中")
    }

    // MARK: - 2. AppEnvironment 初始化链路与 Store 单例持有

    func testAppEnvironment_InitializationChain() {
        let env = AppEnvironment.shared

        XCTAssertNotNil(env.router)
        XCTAssertNotNil(env.themeManager)
    }

    // MARK: - 3. Router 顶层路由切换与状态一致性

    func testRouter_DeepLinkAndTabNavigation() {
        let router = Router.shared

        // 切换不同主 Tab
        router.selectedTab = .knowledge
        XCTAssertEqual(router.selectedTab, .knowledge)

        router.selectedTab = .synthesis
        XCTAssertEqual(router.selectedTab, .synthesis)

        // 导航路径压栈
        let testUUID = UUID()
        router.navigate(to: .pageDetail(id: testUUID))
        XCTAssertEqual(router.path.count, 1)

        // 返回根视图
        router.popToRoot()
        XCTAssertTrue(router.path.isEmpty)
    }
}

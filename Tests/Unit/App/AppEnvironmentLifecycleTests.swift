//
//  AppEnvironmentLifecycleTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 测试层
//  核心职责：验证 AppEnvironment 启动编排、DI 拓扑依赖链完整性与全局单例生命周期分支。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AppEnvironmentLifecycleTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 核心状态与路由单例就绪分支

    func testAppEnvironment_Singletons_Initialized() {
        let env = AppEnvironment.shared

        XCTAssertNotNil(env.router, "全局 Router 应当就绪")
        XCTAssertNotNil(env.themeManager, "全局 ThemeManager 应当就绪")
    }

    // MARK: - 2. DI 容器服务完整性断言分支

    func testServiceContainer_AssertRegisteredServices() {
        // 验证当前测试环境下核心系统能力是否均已正确挂载
        XCTAssertNotNil(ServiceContainer.shared.resolveOptional((any LoggerProtocol).self))
        XCTAssertNotNil(ServiceContainer.shared.resolveOptional((any LLMServiceProtocol).self))
    }
}

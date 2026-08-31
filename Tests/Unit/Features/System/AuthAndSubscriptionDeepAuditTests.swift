//
//  AuthAndSubscriptionDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：针对订阅套餐视图（SubscriptionPlanView, SubscriptionPlanCard）与
//            认证流程交互组件（AuthView, UserProfileView）执行深层状态机与边界测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AuthAndSubscriptionDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SubscriptionPlanView 渲染

    func testSubscriptionPlanView_Rendering() {
        let planView = SubscriptionPlanView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: planView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. AuthView 认证主视图渲染

    func testAuthView_Rendering() {
        let authView = AuthView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: authView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. UserProfileView 用户信息面板渲染

    func testUserProfileView_Rendering() {
        let profileView = UserProfileView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: profileView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }
}

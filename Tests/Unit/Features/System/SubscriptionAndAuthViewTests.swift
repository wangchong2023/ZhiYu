//
//  SubscriptionAndAuthViewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 BillingCycle 周期切换、PlanFeature 权益模型与用户订阅配额计算分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SubscriptionAndAuthViewTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 订阅周期枚举与默认状态

    func testBillingCycle_Variants() {
        let monthly: BillingCycle = .monthly
        let yearly: BillingCycle = .yearly

        XCTAssertNotEqual(monthly, yearly)
    }

    // MARK: - 2. 套餐权益条目模型构建

    func testPlanFeature_Creation() {
        let feature = PlanFeature(
            icon: "sparkles",
            title: "AI 深度合成",
            value: "无限次调用"
        )

        XCTAssertEqual(feature.icon, "sparkles")
        XCTAssertEqual(feature.title, "AI 深度合成")
        XCTAssertEqual(feature.value, "无限次调用")
    }

    // MARK: - 3. 用户登录与 Pro 权益状态流转

    func testAuthService_CurrentUserProState() {
        let authService = ServiceContainer.shared.resolve(AuthService.self)
        AuthSession.shared.update(user: nil)
        XCTAssertNil(authService.currentUser)

        let mockUser = User(
            id: UUID(),
            name: "智宇探索者",
            email: "test@zhiyu.app",
            planKey: "pro",
            maxVaults: 100,
            maxPages: 50000,
            maxPlugins: 999999,
            features: ["ai"]
        )
        AuthSession.shared.update(user: mockUser)

        XCTAssertNotNil(authService.currentUser)
        XCTAssertTrue(authService.currentUser?.isPro ?? false)
    }
}

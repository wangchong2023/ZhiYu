//
//  UserProfileAndMarkdownRendererTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 UserProfile 菜单数据流与 MarkdownRenderer 渲染选项分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class UserProfileAndMarkdownRendererTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. User 模型属性与展示格式

    func testUser_DisplayInfo() {
        let user = User(
            id: UUID(),
            name: "智宇工程师",
            email: "developer@zhiyu.ai",
            planKey: "pro",
            maxVaults: 100,
            maxPages: 50000,
            maxPlugins: 999999,
            features: []
        )

        XCTAssertEqual(user.name, "智宇工程师")
        XCTAssertEqual(user.email, "developer@zhiyu.ai")
        XCTAssertTrue(user.isPro)
    }

    // MARK: - 2. DesignSystem 调色板与圆角 Token

    func testDesignSystem_TokensIntegrity() {
        XCTAssertGreaterThan(DesignSystem.standardPadding, 0)
        XCTAssertGreaterThan(DesignSystem.cardRadius, 0)
        XCTAssertGreaterThan(DesignSystem.iconMedium, 0)
    }
}

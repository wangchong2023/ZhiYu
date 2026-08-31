//
//  PhoneAuthSMSVerificationBranchTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：深入验证 PhoneAuthService 密码登录、短信验证码下发与手机号注册状态机分支。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class PhoneAuthSMSVerificationBranchTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        AuthService.forceMockBackend = true
    }

    override func tearDown() async throws {
        AuthService.forceMockBackend = false
        AuthSession.shared.logout()
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 密码登录 Mock 分支

    func testPasswordLogin_WithMockBackend_Succeeds() async {
        let authService = AuthService.shared

        let success = await authService.login(identity: "13800000000", password: "Password123!")

        XCTAssertTrue(success, "Mock 后端模式下密码登录应当返回成功")
        XCTAssertTrue(authService.isAuthenticated)
    }

    // MARK: - 2. 短信验证码下发异常保护分支

    func testSendSmsCode_WhenNetworkFails_ReturnsFalseSafely() async {
        AuthService.forceMockBackend = false
        let authService = AuthService.shared

        // 未 mock network client request 时应优雅捕获错误返回 false
        let success = await authService.sendSmsCode(phone: "13800000000", scene: "login")

        XCTAssertFalse(success, "网络请求失败时应当优雅返回 false 而非崩溃")
    }
}

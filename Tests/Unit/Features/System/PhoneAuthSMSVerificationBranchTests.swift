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
        // 注入 TestMockURLProtocol 测试 URLSession，隔离真实网络：
        // 防止 backend_base_url 可达时 sendSmsCode 真实请求成功导致断言失败（CVE/环境无关，纯测试确定性）
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestMockURLProtocol.self]
        await NetworkClient.shared.setTestSession(URLSession(configuration: config))
    }

    override func tearDown() async throws {
        await NetworkClient.shared.setTestSession(nil)
        TestMockURLProtocol.requestHandler = nil
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

        // mock 网络层抛错，确定性模拟网络请求失败，返回 false
        TestMockURLProtocol.requestHandler = { _ in
            throw NSError(domain: "TestMockURLProtocol", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "network down"])
        }

        let success = await authService.sendSmsCode(phone: "13800000000", scene: "login")

        XCTAssertFalse(success, "网络请求失败时应当优雅返回 false 而非崩溃")
    }
}

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
        // 注入 TestMockURLProtocol 测试 URLSession，隔离真实网络
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestMockURLProtocol.self]
        await NetworkClient.shared.setTestSession(URLSession(configuration: config))
    }

    override func tearDown() async throws {
        TestMockURLProtocol.requestHandler = nil
        AuthSession.shared.logout()
        // 先登出：在 mock session 仍生效时执行 performLogout，其内部后端 revoke 走 mock 立即返回，
        // 避免先清空 mock session 后走真实网络（后端不可达）导致挂起超时
        await AuthService.shared.performLogout()
        await NetworkClient.shared.setTestSession(nil)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 密码登录模拟网络响应分支

    func testPasswordLogin_WithMockBackend_Succeeds() async {
        let authService = AuthService.shared

        TestMockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else {
                throw URLError(.badServerResponse)
            }
            if url.path.contains(APIPaths.phoneLoginPath) {
                let json = """
                {
                    "code": 0, "message": "success", "requestId": "req", "timestamp": 123,
                    "data": {
                        "accessToken": "mock_token", "refreshToken": "mock_refresh",
                        "expiresIn": 3600, "tokenType": "Bearer", "isNewUser": false, "totpRequired": false
                    }
                }
                """
                return (response, json.data(using: .utf8) ?? Data())
            } else {
                let profile = """
                {"code": 0, "message": "success", "requestId": "req", "timestamp": 123, "data": {"userId": 1, "username": "13800000000", "nick": "User"}}
                """
                return (response, profile.data(using: .utf8) ?? Data())
            }
        }

        let success = await authService.login(identity: "13800000000", password: "Password123!")

        XCTAssertTrue(success, "网络拦截模拟成功时密码登录应当返回成功")
        XCTAssertTrue(authService.isAuthenticated)
    }

    // MARK: - 2. 短信验证码下发异常保护分支

    func testSendSmsCode_WhenNetworkFails_ReturnsFalseSafely() async {
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

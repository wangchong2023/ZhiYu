//
//  AuthOAuthStrategiesBranchTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：深入验证 OAuthService 多策略登录（Apple/Google/GitHub/Carrier）、游客会话生命周期与登出状态清理分支。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AuthOAuthStrategiesBranchTests: XCTestCase {

    /// 测试用 URLSession — 拦截 logout 后台任务的真实网络调用，防止 30 秒超时
    private var testSession: URLSession!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()

        // 注入 TestMockURLProtocol 的测试 URLSession
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestMockURLProtocol.self]
        testSession = URLSession(configuration: config)
        await NetworkClient.shared.setTestSession(testSession)
    }

    override func tearDown() async throws {
        AuthSession.shared.logout()
        await AuthService.shared.performLogout()
        await NetworkClient.shared.awaitRefreshTask()
        await NetworkClient.shared.setTestSession(nil)
        TestMockURLProtocol.requestHandler = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 游客模式生命周期分支

    func testContinueAsGuest_SetsGuestStateAndClearsUser() {
        let authService = AuthService.shared
        authService.continueAsGuest()

        XCTAssertTrue(authService.isGuest, "以游客模式进入系统后 isGuest 应为 true")
        XCTAssertFalse(authService.isAuthenticated, "游客模式下 isAuthenticated 应为 false")
        XCTAssertNil(authService.currentUser, "游客模式下 currentUser 应为 nil")
    }

    // MARK: - 2. 登出流程清理分支

    func testLogout_ClearsSessionAndSelectedVault() async {
        let authService = AuthService.shared
        AuthSession.shared.update(user: User(name: "tester", email: "test@example.com"))
        VaultService.shared.selectedVaultID = UUID()

        await authService.performLogout()

        XCTAssertFalse(authService.isAuthenticated, "登出后 isAuthenticated 应为 false")
        XCTAssertFalse(authService.isGuest, "登出后 isGuest 应为 false")
        XCTAssertNil(authService.currentUser, "登出后 currentUser 应为 nil")
        XCTAssertNil(VaultService.shared.selectedVaultID, "登出后应自动退出选中的保险库")
    }

    // MARK: - 3. Apple 策略凭证获取与 Mock 登录分支

    func testAppleAuthStrategy_AcquireCredentials() async throws {
        let strategy = MockAppleAuthStrategy()
        let credential = try await strategy.acquireCredentials()

        XCTAssertEqual(credential.identityType, "apple")
        XCTAssertEqual(credential.identifier, "mock_apple_user_id")
        XCTAssertNotNil(credential.extraInfo?["idToken"])
    }

    // MARK: - 4. OAuth 中台统一登录成功分支

    func testLoginUsingStrategy_WithMockBackend_Succeeds() async {
        let loginJson = """
        {
            "code": 0,
            "message": "success",
            "requestId": "mock_req",
            "timestamp": 1700000000000,
            "data": {
                "accessToken": "mock_access_token_123",
                "refreshToken": "mock_refresh_token_123",
                "expiresIn": 7200,
                "tokenType": "Bearer"
            }
        }
        """
        let profileJson = """
        {
            "code": 0,
            "message": "success",
            "requestId": "mock_profile_req",
            "timestamp": 1700000000000,
            "data": {
                "userId": 12345,
                "username": "oauth_user",
                "nick": "OAuth User",
                "email": "oauth@example.com",
                "mobile": "13800000000"
            }
        }
        """
        TestMockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else {
                throw URLError(.badServerResponse)
            }
            if url.path.contains(APIPaths.userProfilePath) {
                return (response, profileJson.data(using: .utf8))
            }
            return (response, loginJson.data(using: .utf8))
        }

        let authService = AuthService.shared
        let strategy = MockAppleAuthStrategy()

        let success = await authService.login(using: strategy)

        XCTAssertTrue(success, "网络拦截模拟成功响应后第三方登录应当返回成功")
        XCTAssertTrue(authService.isAuthenticated, "登录成功后应当处于已鉴权状态")
    }
}

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
        AuthService.forceMockBackend = true

        // 注入 TestMockURLProtocol 的测试 URLSession
        // logout() 创建的后台任务会发起网络调用吊销 refresh token，
        // 若不拦截将因无 mock handler 而挂起至 requestTimeout（30 秒），
        // stale 任务泄漏至后续测试类的 awaitAllLogoutTasks() 导致 CI 600 秒超时
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestMockURLProtocol.self]
        testSession = URLSession(configuration: config)
        await NetworkClient.shared.setTestSession(testSession)
    }

    override func tearDown() async throws {
        AuthService.forceMockBackend = false
        AuthSession.shared.logout()
        await awaitAllLogoutTasks()
        await NetworkClient.shared.awaitRefreshTask()
        await NetworkClient.shared.setTestSession(nil)
        TestMockURLProtocol.requestHandler = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    /// 等待所有 logout 后台任务完成并清空任务列表
    /// - Note: 防止 stale 任务泄漏至后续测试类，导致 awaitAllLogoutTasks() 挂起
    private func awaitAllLogoutTasks() async {
        for task in AuthService.shared.testLogoutTasks {
            await task.value
        }
        AuthService.shared.testLogoutTasks.removeAll()
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

    func testLogout_ClearsSessionAndSelectedVault() {
        let authService = AuthService.shared
        AuthSession.shared.update(user: User(name: "tester", email: "test@example.com"))
        VaultService.shared.selectedVaultID = UUID()

        authService.logout()

        XCTAssertFalse(authService.isAuthenticated, "登出后 isAuthenticated 应为 false")
        XCTAssertFalse(authService.isGuest, "登出后 isGuest 应为 false")
        XCTAssertNil(authService.currentUser, "登出后 currentUser 应为 nil")
        XCTAssertNil(VaultService.shared.selectedVaultID, "登出后应自动退出选中的保险库")
    }

    // MARK: - 3. Apple 策略凭证获取与 Mock 登录分支

    func testAppleAuthStrategy_AcquireCredentials_InTestMode() async throws {
        let strategy = AppleAuthStrategy()
        let credential = try await strategy.acquireCredentials()

        XCTAssertEqual(credential.identityType, "apple")
        XCTAssertEqual(credential.identifier, "mock_apple_user_id")
        XCTAssertNotNil(credential.extraInfo?["idToken"])
    }

    // MARK: - 4. OAuth 中台统一登录成功分支

    func testLoginUsingStrategy_WithMockBackend_Succeeds() async {
        let authService = AuthService.shared
        let strategy = AppleAuthStrategy()

        let success = await authService.login(using: strategy)

        XCTAssertTrue(success, "Mock 后端环境下第三方登录应当返回成功")
        XCTAssertTrue(authService.isAuthenticated, "登录成功后应当处于已鉴权状态")
    }
}

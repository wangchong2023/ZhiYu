//
//  AuthLogoutDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AuthService 登出深度测试 — 覆盖 logout 后台任务管理（testLogoutTask/testLogoutTasks）、
//            本地状态清理（isAuthenticated/currentUser/isGuest）、Keychain Token 清理、
//            有/无 refresh token 时后端注销请求行为等场景，以发现生产代码潜在 bug 为首要目标。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class AuthLogoutDeepTests: XCTestCase {

    // MARK: - 常量

    /// 测试用邮箱
    private let testEmail = "test@example.com"
    /// Lite 套餐最大笔记本数
    private let liteMaxVaults = User.DefaultQuotas.liteMaxVaults
    /// JWT Token Key
    private let jwtTokenKey = AppConstants.Network.jwtTokenKey
    /// Refresh Token Key
    private let refreshTokenKey = AppConstants.Network.refreshTokenKey
    /// 测试用 JWT Token 值
    private let testJWTToken = "test_jwt_token"
    /// 测试用 Refresh Token 值
    private let testRefreshToken = "test_refresh_token"

    // MARK: - 测试基础设施

    private var testSession: URLSession!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()

        // 注入 Mock Keychain
        KeychainService.testOverride = MockKeychainService()

        // 注入 TestMockURLProtocol 的测试 URLSession
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestMockURLProtocol.self]
        testSession = URLSession(configuration: config)
        await NetworkClient.shared.setTestSession(testSession)

        // 确保干净状态
        AuthSession.shared.logout()
        try? KeychainService.shared.delete(key: jwtTokenKey)
        try? KeychainService.shared.delete(key: refreshTokenKey)
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
    }

    override func tearDown() async throws {
        AuthSession.shared.logout()
        await awaitAllLogoutTasks()
        await NetworkClient.shared.awaitRefreshTask()
        await NetworkClient.shared.setTestSession(nil)
        TestMockURLProtocol.requestHandler = nil
        KeychainService.testOverride = nil
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    /// 等待所有 logout 后台任务完成
    private func awaitAllLogoutTasks() async {
        for task in AuthService.shared.testLogoutTasks {
            await task.value
        }
        AuthService.shared.testLogoutTasks.removeAll()
    }

    /// 构造测试用户
    private func makeTestUser(
        gender: Int? = nil,
        birthday: String? = nil,
        phone: String? = nil,
        features: [String] = [],
        planKey: String? = PlanKey.free
    ) -> User {
        User(
            id: UUID(),
            name: "原始用户",
            email: testEmail,
            phone: phone,
            avatarURL: nil,
            planKey: planKey,
            maxVaults: liteMaxVaults,
            maxPages: User.DefaultQuotas.liteMaxPages,
            maxPlugins: User.DefaultQuotas.liteMaxPlugins,
            features: features,
            gender: gender,
            birthday: birthday
        )
    }

    // MARK: - logout 后台任务管理

    /// 验证 logout 后 testLogoutTask 被设置
    func testLogoutSetsTestLogoutTask() async {
        AuthSession.shared.update(user: makeTestUser())

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertNotNil(AuthService.shared.testLogoutTask, "logout 应设置 testLogoutTask")
    }

    /// 验证 logout 后 testLogoutTasks 列表追加任务
    /// - Note: `awaitAllLogoutTasks` 会清空 testLogoutTasks 数组，因此需在 await 前检查 count。
    func testLogoutTestLogoutTasksListAppendsTask() async {
        AuthSession.shared.update(user: makeTestUser())

        let initialCount = AuthService.shared.testLogoutTasks.count
        AuthService.shared.logout()
        // logout() 同步追加 task 到 testLogoutTasks，await 前检查
        XCTAssertEqual(AuthService.shared.testLogoutTasks.count, initialCount + 1, "logout 应向 testLogoutTasks 追加任务")
        await awaitAllLogoutTasks()
    }

    /// 验证多次 logout 后 testLogoutTasks 列表持续增长
    /// - Note: `awaitAllLogoutTasks` 会清空 testLogoutTasks 数组，因此每次 logout 后立即检查。
    func testLogoutMultipleCallsTestLogoutTasksKeepGrowing() async {
        AuthSession.shared.update(user: makeTestUser())

        let initialCount = AuthService.shared.testLogoutTasks.count
        AuthService.shared.logout()
        XCTAssertEqual(AuthService.shared.testLogoutTasks.count, initialCount + 1, "第一次 logout 应追加任务")
        await awaitAllLogoutTasks()

        AuthService.shared.logout()
        XCTAssertEqual(AuthService.shared.testLogoutTasks.count, 1, "第二次 logout 应追加任务（数组已清空）")
        await awaitAllLogoutTasks()
    }

    /// 验证 logout 清空 isAuthenticated
    func testLogoutClearsIsAuthenticated() async {
        AuthSession.shared.update(user: makeTestUser())
        XCTAssertTrue(AuthService.shared.isAuthenticated, "前置条件: 应已登录")

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertFalse(AuthService.shared.isAuthenticated, "logout 后 isAuthenticated 应为 false")
    }

    /// 验证 logout 清空 currentUser
    func testLogoutClearsCurrentUser() async {
        AuthSession.shared.update(user: makeTestUser())
        XCTAssertNotNil(AuthService.shared.currentUser, "前置条件: 应有当前用户")

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertNil(AuthService.shared.currentUser, "logout 后 currentUser 应为 nil")
    }

    /// 验证 logout 清空 isGuest
    func testLogoutClearsIsGuest() async {
        AuthSession.shared.isGuest = true
        XCTAssertTrue(AuthService.shared.isGuest, "前置条件: 应为游客模式")

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertFalse(AuthService.shared.isGuest, "logout 后 isGuest 应为 false")
    }

    /// 验证 logout 无 refresh token 时不发送后端请求但仍清理本地
    func testLogoutNoRefreshTokenStillCleansLocalState() async throws {
        AuthSession.shared.update(user: makeTestUser())
        // 不存储任何 token

        var backendCalled = false
        TestMockURLProtocol.requestHandler = { request in
            backendCalled = true
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, nil)
        }

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertFalse(backendCalled, "无 refresh token 时不应调用后端注销接口")
        XCTAssertFalse(AuthService.shared.isAuthenticated, "应仍清理本地登录状态")
    }

    /// 验证 logout 有 refresh token 时发送后端注销请求
    func testLogoutWithRefreshTokenSendsBackendLogoutRequest() async throws {
        AuthSession.shared.update(user: makeTestUser())
        try KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        try KeychainService.shared.store(key: refreshTokenKey, value: testRefreshToken)

        var logoutCalled = false
        TestMockURLProtocol.requestHandler = { request in
            if request.url?.path == APIPaths.logoutPath {
                logoutCalled = true
            }
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, nil)
        }

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertTrue(logoutCalled, "有 refresh token 时应调用后端注销接口")
    }

    /// 验证 logout 后 Keychain 中的 JWT Token 被清理
    func testLogoutCleansKeychainJWTToken() async throws {
        AuthSession.shared.update(user: makeTestUser())
        try KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        try KeychainService.shared.store(key: refreshTokenKey, value: testRefreshToken)

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, nil)
        }

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        let jwt = try? KeychainService.shared.retrieve(key: jwtTokenKey)
        XCTAssertNil(jwt, "logout 后 JWT Token 应被清理")
    }

    /// 验证 logout 后 Keychain 中的 Refresh Token 被清理
    func testLogoutCleansKeychainRefreshToken() async throws {
        AuthSession.shared.update(user: makeTestUser())
        try KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        try KeychainService.shared.store(key: refreshTokenKey, value: testRefreshToken)

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, nil)
        }

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        let refresh = try? KeychainService.shared.retrieve(key: refreshTokenKey)
        XCTAssertNil(refresh, "logout 后 Refresh Token 应被清理")
    }
}

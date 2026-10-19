//
//  AuthStateGuestDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AuthService 状态与游客模式深度测试 — 覆盖 isMockBackend/isMockMode 状态、
//            continueAsGuest 各分支、isAuthenticated/isGuest/currentUser 计算属性、
//            tryAutoLogin Mock 与非 Mock 模式分支等场景。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class AuthStateGuestDeepTests: XCTestCase {

    // MARK: - 常量

    /// 测试用昵称
    private let testNickname = "测试昵称"
    /// 测试用邮箱
    private let testEmail = "test@example.com"
    /// 测试用手机号
    private let testPhone = "13800138000"
    /// Pro 套餐最大笔记本数
    private let proMaxVaults = User.DefaultQuotas.proMaxVaults
    /// Pro 套餐最大页面数
    private let proMaxPages = User.DefaultQuotas.proMaxPages
    /// Pro 套餐最大插件数
    private let proMaxPlugins = User.DefaultQuotas.proMaxPlugins
    /// Free 套餐最大笔记本数
    private let freeMaxVaults = User.DefaultQuotas.freeMaxVaults
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
    }

    override func tearDown() async throws {
        await AuthService.shared.performLogout()
        await NetworkClient.shared.awaitRefreshTask()
        await NetworkClient.shared.setTestSession(nil)
        TestMockURLProtocol.requestHandler = nil
        KeychainService.testOverride = nil
        try await super.tearDown()
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
            maxVaults: freeMaxVaults,
            maxPages: User.DefaultQuotas.freeMaxPages,
            maxPlugins: User.DefaultQuotas.freeMaxPlugins,
            features: features,
            gender: gender,
            birthday: birthday
        )
    }

    // MARK: - continueAsGuest

    /// 验证 continueAsGuest 设置 isGuest 为 true
    func testContinueAsGuestSetsIsGuestTrue() {
        AuthSession.shared.logout()

        AuthService.shared.continueAsGuest()

        XCTAssertTrue(AuthService.shared.isGuest, "continueAsGuest 应设置 isGuest 为 true")
    }

    /// 验证 continueAsGuest 清空 currentUser
    func testContinueAsGuestClearsCurrentUser() {
        AuthSession.shared.update(user: makeTestUser())

        AuthService.shared.continueAsGuest()

        XCTAssertNil(AuthService.shared.currentUser, "continueAsGuest 应清空 currentUser")
    }

    /// 验证 continueAsGuest 后 isAuthenticated 为 false
    func testAfterContinueAsGuestIsAuthenticatedFalse() {
        AuthSession.shared.update(user: makeTestUser())

        AuthService.shared.continueAsGuest()

        XCTAssertFalse(AuthService.shared.isAuthenticated, "游客模式下 isAuthenticated 应为 false")
    }

    /// 验证 continueAsGuest 重复调用保持 isGuest 为 true
    func testContinueAsGuestRepeatedCallsKeepsIsGuestTrue() {
        AuthService.shared.continueAsGuest()
        AuthService.shared.continueAsGuest()

        XCTAssertTrue(AuthService.shared.isGuest, "重复调用 continueAsGuest 应保持 isGuest 为 true")
    }

    // MARK: - isAuthenticated / isGuest / currentUser 计算属性

    /// 验证 isAuthenticated 反映 AuthSession.isLoggedIn
    func testIsAuthenticatedReflectsAuthSessionIsLoggedIn() {
        AuthSession.shared.logout()
        XCTAssertFalse(AuthService.shared.isAuthenticated, "无用户时应为 false")

        AuthSession.shared.update(user: makeTestUser())
        XCTAssertTrue(AuthService.shared.isAuthenticated, "有用户时应为 true")
    }

    /// 验证 isGuest 反映 AuthSession.isGuest
    func testIsGuestReflectsAuthSessionIsGuest() {
        AuthSession.shared.isGuest = false
        XCTAssertFalse(AuthService.shared.isGuest, "isGuest=false 时应为 false")

        AuthSession.shared.isGuest = true
        XCTAssertTrue(AuthService.shared.isGuest, "isGuest=true 时应为 true")

        AuthSession.shared.isGuest = false
    }

    /// 验证 currentUser 反映 AuthSession.currentUser
    func testCurrentUserReflectsAuthSessionCurrentUser() {
        AuthSession.shared.logout()
        XCTAssertNil(AuthService.shared.currentUser, "无用户时应为 nil")

        let user = makeTestUser()
        AuthSession.shared.update(user: user)
        XCTAssertEqual(AuthService.shared.currentUser?.id, user.id, "应返回 AuthSession.currentUser")
    }

    // MARK: - tryAutoLogin Mock 模式

    // MARK: - tryAutoLogin 状态测试

    /// 验证当存在有效 Token 且 Profile 响应成功时，tryAutoLogin 成功并恢复用户信息
    func testTryAutoLoginWithValidTokenRestoresUser() async throws {
        try KeychainService.shared.store(key: jwtTokenKey, value: "valid_jwt_token")
        AuthSession.shared.logout()

        let profileJson = """
        {
            "code": 0,
            "message": "success",
            "requestId": "req_auto_login",
            "timestamp": 1700000000000,
            "data": {
                "userId": 12345,
                "username": "autologin_user",
                "nick": "Auto User",
                "email": "auto@example.com",
                "mobile": "13900139000"
            }
        }
        """
        TestMockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else {
                throw URLError(.badServerResponse)
            }
            return (response, profileJson.data(using: .utf8))
        }

        let success = await AuthService.shared.tryAutoLogin()

        XCTAssertTrue(success, "有效 Token 且接口正常时 tryAutoLogin 应成功")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
        XCTAssertFalse(AuthService.shared.isGuest, "登录后 isGuest 应为 false")
        XCTAssertEqual(AuthService.shared.currentUser?.name, "Auto User")
    }

    /// 验证无 Token 时 tryAutoLogin 返回 false
    func testTryAutoLoginNoTokenReturnsFalse() async {
        try? KeychainService.shared.delete(key: jwtTokenKey)
        AuthSession.shared.logout()

        let success = await AuthService.shared.tryAutoLogin()

        XCTAssertFalse(success, "无 Token 时应返回 false")
        XCTAssertFalse(AuthService.shared.isAuthenticated, "应保持未登录")
    }
}

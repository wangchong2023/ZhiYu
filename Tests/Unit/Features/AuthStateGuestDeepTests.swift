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

    // MARK: - isMockBackend / isMockMode 状态

    /// 验证非 DEBUG Mock 模式下 isMockBackend 为 false
    func testIsMockBackendNonMockModeReturnsFalse() {
        #if DEBUG
        AuthService.forceMockBackend = false
        XCTAssertFalse(AuthService.shared.isMockBackend, "非 Mock 模式下 isMockBackend 应为 false")
        XCTAssertFalse(AuthService.shared.isMockMode, "非 Mock 模式下 isMockMode 应为 false")
        #endif
    }

    /// 验证 forceMockBackend 启用时 isMockBackend 为 true
    func testIsMockBackendForceMockBackendEnabledReturnsTrue() {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        XCTAssertTrue(AuthService.shared.isMockBackend, "forceMockBackend 启用时 isMockBackend 应为 true")
        XCTAssertTrue(AuthService.shared.isMockMode, "forceMockBackend 启用时 isMockMode 应为 true")
        #endif
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

    /// 验证 Mock 模式下 tryAutoLogin 成功并注入 Mock 用户
    func testTryAutoLoginMockModeSuccessInjectsMockUser() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()

        let success = await AuthService.shared.tryAutoLogin()

        XCTAssertTrue(success, "Mock 模式下 tryAutoLogin 应成功")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
        XCTAssertEqual(AuthService.shared.currentUser?.name, "Mock Autologin User", "应注入 Mock 用户")
        #endif
    }

    /// 验证 Mock 模式下 tryAutoLogin 设置 isGuest 为 false
    func testTryAutoLoginMockModeSetsIsGuestFalse() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.isGuest = true

        let success = await AuthService.shared.tryAutoLogin()

        XCTAssertTrue(success, "Mock 模式下应成功")
        XCTAssertFalse(AuthService.shared.isGuest, "tryAutoLogin 成功后 isGuest 应为 false")
        #endif
    }

    // MARK: - tryAutoLogin 非 Mock 模式

    /// 验证非 Mock 模式下 tryAutoLogin 无 Token 时返回 false
    func testTryAutoLoginNonMockModeNoTokenReturnsFalse() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.delete(key: jwtTokenKey)
        AuthSession.shared.logout()

        let success = await AuthService.shared.tryAutoLogin()

        XCTAssertFalse(success, "无 Token 时应返回 false")
        XCTAssertFalse(AuthService.shared.isAuthenticated, "应保持未登录")
    }
}

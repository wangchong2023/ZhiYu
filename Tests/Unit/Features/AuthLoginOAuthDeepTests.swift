//
//  AuthLoginOAuthDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AuthService 登录、短信验证码、注册与 OAuth 深度测试 — 覆盖 login 密码/OAuth
//            Mock 与非 Mock 模式、sendSmsCode 成功与失败、register 网络失败等场景，
//            以发现生产代码潜在 bug 为首要目标。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class AuthLoginOAuthDeepTests: XCTestCase {

    // MARK: - 常量

    /// 测试用手机号
    private let testPhone = "13800138000"
    /// JWT Token Key
    private let jwtTokenKey = AppConstants.Network.jwtTokenKey

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

    // MARK: - login Mock 模式

    /// 验证 Mock 模式下密码登录成功
    func testLoginMockModePasswordLoginSuccess() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()

        let success = await AuthService.shared.login(identity: "testuser", password: "testpass")

        XCTAssertTrue(success, "Mock 模式下密码登录应成功")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
        XCTAssertEqual(AuthService.shared.currentUser?.name, "testuser", "用户名应为 identity")
        #endif
    }

    /// 验证 Mock 模式下密码登录写入 Keychain Token
    func testLoginMockModePasswordLoginWritesKeychainToken() async throws {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()
        try? KeychainService.shared.delete(key: jwtTokenKey)

        let success = await AuthService.shared.login(identity: "testuser", password: "testpass")

        XCTAssertTrue(success, "登录应成功")
        let jwt = try? KeychainService.shared.retrieve(key: jwtTokenKey)
        XCTAssertNotNil(jwt, "登录后 Keychain 应有 JWT Token")
        #endif
    }

    // MARK: - login 非 Mock 模式

    /// 验证非 Mock 模式下密码登录网络失败返回 false
    func testLoginNonMockModeNetworkFailureReturnsFalse() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil))
            return (response, Data())
        }

        let success = await AuthService.shared.login(identity: "testuser", password: "testpass")

        XCTAssertFalse(success, "网络失败应返回 false")
        XCTAssertFalse(AuthService.shared.isAuthenticated, "应保持未登录")
    }

    // MARK: - sendSmsCode 非 Mock 模式

    /// 验证非 Mock 模式下 sendSmsCode 网络失败返回 false
    func testSendSmsCodeNonMockModeNetworkFailureReturnsFalse() async {
        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil))
            return (response, Data())
        }

        let success = await AuthService.shared.sendSmsCode(phone: testPhone, scene: "login")

        XCTAssertFalse(success, "网络失败应返回 false")
    }

    /// 验证非 Mock 模式下 sendSmsCode 成功返回 true
    func testSendSmsCodeNonMockModeSuccessReturnsTrue() async {
        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))
            let json: [String: Any] = [
                "code": 0,
                "message": "success",
                "data": NSNull(),
                "requestId": "req",
                "timestamp": 123
            ]
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        let success = await AuthService.shared.sendSmsCode(phone: testPhone, scene: "login")

        XCTAssertTrue(success, "成功响应应返回 true")
    }

    // MARK: - register 非 Mock 模式

    /// 验证非 Mock 模式下 register 网络失败返回 false
    func testRegisterNonMockModeNetworkFailureReturnsFalse() async {
        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil))
            return (response, Data())
        }

        let success = await AuthService.shared.register(phone: testPhone, code: "123456", password: "")

        XCTAssertFalse(success, "网络失败应返回 false")
    }

    // MARK: - OAuth login Mock 模式

    /// 验证 Mock 模式下 Carrier 登录成功
    func testLoginMockModeCarrierLoginSuccess() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()

        let success = await AuthService.shared.login(using: CarrierAuthStrategy())

        XCTAssertTrue(success, "Mock 模式下 Carrier 登录应成功")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
        #endif
    }

    /// 验证 Mock 模式下 GitHub 登录成功
    func testLoginMockModeGitHubLoginSuccess() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()

        let success = await AuthService.shared.login(using: GitHubAuthStrategy())

        XCTAssertTrue(success, "Mock 模式下 GitHub 登录应成功")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
        #endif
    }

    /// 验证 Mock 模式下 WeChat 登录成功
    func testLoginMockModeWeChatLoginSuccess() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()

        let success = await AuthService.shared.login(using: WeChatAuthStrategy())

        XCTAssertTrue(success, "Mock 模式下 WeChat 登录应成功")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
        #endif
    }
}

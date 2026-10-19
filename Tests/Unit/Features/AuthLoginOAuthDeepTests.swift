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
    }

    override func tearDown() async throws {
        AuthSession.shared.logout()
        await AuthService.shared.performLogout()
        await NetworkClient.shared.awaitRefreshTask()
        await NetworkClient.shared.setTestSession(nil)
        TestMockURLProtocol.requestHandler = nil
        KeychainService.testOverride = nil
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    /// 设置 Mock 登录成功响应
    private func setupMockLoginSuccessResponse(username: String = "testuser") {
        let loginJson = """
        {
            "code": 0,
            "message": "success",
            "requestId": "mock_req",
            "timestamp": 1700000000000,
            "data": {
                "accessToken": "mock_jwt_token_12345",
                "refreshToken": "mock_refresh_token_12345",
                "expiresIn": 7200,
                "tokenType": "Bearer",
                "isNewUser": false,
                "totpRequired": false
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
                "username": "\(username)",
                "nick": "Test User",
                "email": "test@example.com",
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
            } else {
                return (response, loginJson.data(using: .utf8))
            }
        }
    }

    // MARK: - login 模拟网络响应模式

    /// 验证网络拦截模拟下密码登录成功

    func testLoginMockModePasswordLoginSuccess() async {
        setupMockLoginSuccessResponse(username: "testuser")
        AuthSession.shared.logout()

        let success = await AuthService.shared.login(identity: "testuser", password: "testpass")

        XCTAssertTrue(success, "模拟网络拦截下密码登录应成功")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
        XCTAssertEqual(AuthService.shared.currentUser?.name, "Test User")
    }

    /// 验证网络拦截模拟下密码登录写入 Keychain Token
    func testLoginMockModePasswordLoginWritesKeychainToken() async throws {
        setupMockLoginSuccessResponse(username: "testuser")
        AuthSession.shared.logout()
        try? KeychainService.shared.delete(key: jwtTokenKey)

        let success = await AuthService.shared.login(identity: "testuser", password: "testpass")

        XCTAssertTrue(success, "登录应成功")
        let jwt = try? KeychainService.shared.retrieve(key: jwtTokenKey)
        XCTAssertNotNil(jwt, "登录后 Keychain 应有 JWT Token")
    }

    // MARK: - login 非 Mock 模式

    /// 验证网络失败时密码登录返回 false
    func testLoginNonMockModeNetworkFailureReturnsFalse() async {
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

    // MARK: - OAuth login 模拟网络响应模式

    /// 验证模拟网络响应下 Carrier 登录成功
    func testLoginMockModeCarrierLoginSuccess() async {
        setupMockLoginSuccessResponse()
        AuthSession.shared.logout()

        let success = await AuthService.shared.login(using: MockCarrierAuthStrategy())

        XCTAssertTrue(success, "Carrier 登录应成功")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
    }

    /// 验证模拟网络响应下 GitHub 登录成功
    func testLoginMockModeGitHubLoginSuccess() async {
        setupMockLoginSuccessResponse()
        AuthSession.shared.logout()

        let success = await AuthService.shared.login(using: MockGitHubAuthStrategy())

        XCTAssertTrue(success, "GitHub 登录应成功")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
    }

    /// 验证模拟网络响应下 WeChat 登录成功
    func testLoginMockModeWeChatLoginSuccess() async {
        setupMockLoginSuccessResponse()
        AuthSession.shared.logout()

        let success = await AuthService.shared.login(using: MockWeChatAuthStrategy())

        XCTAssertTrue(success, "WeChat 登录应成功")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
    }
}

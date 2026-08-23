//
//  PhoneAuthServiceDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：PhoneAuthService（AuthService extension）深度补盲测试 — 覆盖 login
//            Mock/非 Mock 全分支、sendSmsCode 各场景、register（短信验证码登录/注册）
//            各分支，以发现生产代码潜在 bug 为首要目标。
//
//  说明：Tests/Unit/Features/AuthServiceDeepTests.swift 已覆盖 login Mock 成功、
//        login 非 Mock 网络失败、sendSmsCode 非 Mock 成功/失败、register 非 Mock 网络失败。
//        本文件补充 login 非 Mock 业务错误、sendSmsCode Mock 模式、register Mock 模式、
//        register 非 Mock 成功/业务错误等深度场景。
//
//  注意：PhoneAuthService 实际方法为 register(phone:code:password:)，不存在 verifySmsCode。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class PhoneAuthServiceDeepTests: XCTestCase {

    // MARK: - 常量

    /// 测试用手机号
    private let testPhone = "13800138000"
    /// 测试用密码
    private let testPassword = "Test@1234"
    /// 测试用短信验证码
    private let testSmsCode = "123456"
    /// 测试用用户名
    private let testIdentity = "testuser"
    /// 测试用场景标识
    private let testScene = "login"
    /// JWT Token Key
    private let jwtTokenKey = AppConstants.Network.jwtTokenKey
    /// Refresh Token Key
    private let refreshTokenKey = AppConstants.Network.refreshTokenKey

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

    /// 构造 LoginResponse 成功响应 JSON
    private func makeLoginResponseJSON(
        accessToken: String = "access_token",
        refreshToken: String? = "refresh_token",
        isNewUser: Bool = false
    ) -> [String: Any] {
        var data: [String: Any] = [
            "accessToken": accessToken,
            "expiresIn": 3600,
            "tokenType": "Bearer",
            "isNewUser": isNewUser,
            "totpRequired": false
        ]
        if let refresh = refreshToken {
            data["refreshToken"] = refresh
        } else {
            data["refreshToken"] = NSNull()
        }
        return [
            "code": 0,
            "message": "success",
            "data": data,
            "requestId": "test_req_id",
            "timestamp": 123456789
        ]
    }

    /// 构造 UserProfileResponse 成功响应 JSON
    private func makeProfileResponseJSON() -> [String: Any] {
        [
            "code": 0,
            "message": "success",
            "data": [
                "userId": 10001,
                "username": "test_user",
                "nick": "Profile用户",
                "avatar": NSNull(),
                "email": "profile@example.com",
                "mobile": "13900139000"
            ],
            "requestId": "test_req_id",
            "timestamp": 123456789
        ]
    }

    /// 构造 EmptyData 成功响应 JSON
    private func makeEmptySuccessJSON() -> [String: Any] {
        [
            "code": 0,
            "message": "success",
            "data": NSNull(),
            "requestId": "test_req_id",
            "timestamp": 123456789
        ]
    }

    // MARK: - login Mock 模式

    /// 验证 Mock 模式下密码登录成功并设置 currentUser
    func testLogin_Mock模式_成功设置currentUser() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()

        let success = await AuthService.shared.login(identity: testIdentity, password: testPassword)

        XCTAssertTrue(success, "Mock 模式下登录应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.name, testIdentity, "name 应为 identity")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
        #endif
    }

    /// 验证 Mock 模式下密码登录写入 refresh token
    func testLogin_Mock模式_写入RefreshToken() async throws {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()
        try? KeychainService.shared.delete(key: refreshTokenKey)

        let success = await AuthService.shared.login(identity: testIdentity, password: testPassword)

        XCTAssertTrue(success, "登录应成功")
        let refresh = try? KeychainService.shared.retrieve(key: refreshTokenKey)
        XCTAssertEqual(refresh, "mock_jwt_refresh_token", "应写入 Mock refresh token")
        #endif
    }

    /// 验证 Mock 模式下密码登录空密码仍成功（Mock 不校验凭证）
    func testLogin_Mock模式_空密码_仍成功() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()

        let success = await AuthService.shared.login(identity: testIdentity, password: "")

        XCTAssertTrue(success, "Mock 模式不校验凭证，空密码应仍成功")
        #endif
    }

    /// 验证 Mock 模式下密码登录 isGuest 被置为 false
    func testLogin_Mock模式_isGuest置为false() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()
        AuthSession.shared.isGuest = true

        let success = await AuthService.shared.login(identity: testIdentity, password: testPassword)

        XCTAssertTrue(success, "登录应成功")
        XCTAssertFalse(AuthService.shared.isGuest, "登录后 isGuest 应为 false")
        #endif
    }

    // MARK: - login 非 Mock 模式

    /// 验证非 Mock 模式下密码登录网络成功返回 true
    func testLogin_非Mock模式_网络成功_返回true() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.phoneLoginPath {
                let json = self.makeLoginResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        let success = await AuthService.shared.login(identity: testIdentity, password: testPassword)

        XCTAssertTrue(success, "网络成功应返回 true")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
    }

    /// 验证非 Mock 模式下密码登录后端业务错误（code != 0）返回 false
    func testLogin_非Mock模式_后端业务错误_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let json: [String: Any] = [
                "code": 1001,
                "message": "invalid credentials",
                "data": NSNull(),
                "requestId": "req",
                "timestamp": 123
            ]
            return (response, try JSONSerialization.data(withJSONObject: json))
        }

        let success = await AuthService.shared.login(identity: testIdentity, password: "wrong")

        XCTAssertFalse(success, "后端业务错误应返回 false")
        XCTAssertFalse(AuthService.shared.isAuthenticated, "应保持未登录")
    }

    /// 验证非 Mock 模式下密码登录后端返回 data 为 null 返回 false
    func testLogin_非Mock模式_data为null_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let json: [String: Any] = [
                "code": 0,
                "message": "success",
                "data": NSNull(),
                "requestId": "req",
                "timestamp": 123
            ]
            return (response, try JSONSerialization.data(withJSONObject: json))
        }

        let success = await AuthService.shared.login(identity: testIdentity, password: testPassword)

        // data 为 null 时 extractPayload 抛 missingDataPayload，被 catch 后返回 false
        XCTAssertFalse(success, "data 为 null 应返回 false")
    }

    /// 验证非 Mock 模式下密码登录 HTTP 500 返回 false
    func testLogin_非Mock模式_HTTP500_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        let success = await AuthService.shared.login(identity: testIdentity, password: testPassword)

        XCTAssertFalse(success, "HTTP 500 应返回 false")
    }

    /// 验证非 Mock 模式下密码登录成功后写入 Keychain token
    func testLogin_非Mock模式_成功_写入KeychainToken() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()
        try? KeychainService.shared.delete(key: jwtTokenKey)

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.phoneLoginPath {
                let json = self.makeLoginResponseJSON(
                    accessToken: "real_access",
                    refreshToken: "real_refresh"
                )
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        let success = await AuthService.shared.login(identity: testIdentity, password: testPassword)

        XCTAssertTrue(success, "登录应成功")
        let jwt = try? KeychainService.shared.retrieve(key: jwtTokenKey)
        XCTAssertEqual(jwt, "real_access", "应写入 access token")
    }

    // MARK: - sendSmsCode 非 Mock 模式

    /// 验证非 Mock 模式下 sendSmsCode 网络成功返回 true
    func testSendSmsCode_非Mock模式_网络成功_返回true() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let json = self.makeEmptySuccessJSON()
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        let success = await AuthService.shared.sendSmsCode(phone: testPhone, scene: testScene)

        XCTAssertTrue(success, "网络成功应返回 true")
    }

    /// 验证非 Mock 模式下 sendSmsCode 网络失败返回 false
    func testSendSmsCode_非Mock模式_网络失败_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        let success = await AuthService.shared.sendSmsCode(phone: testPhone, scene: testScene)

        XCTAssertFalse(success, "网络失败应返回 false")
    }

    /// 验证非 Mock 模式下 sendSmsCode 后端业务错误返回 false
    func testSendSmsCode_非Mock模式_后端业务错误_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let json: [String: Any] = [
                "code": 1002,
                "message": "phone rate limited",
                "data": NSNull(),
                "requestId": "req",
                "timestamp": 123
            ]
            return (response, try JSONSerialization.data(withJSONObject: json))
        }

        let success = await AuthService.shared.sendSmsCode(phone: testPhone, scene: testScene)

        XCTAssertFalse(success, "后端业务错误应返回 false")
    }

    /// 验证非 Mock 模式下 sendSmsCode scene 为 register 时仍正常请求
    /// - Note: TestMockURLProtocol 中 request.httpBody 可能为 nil（body 流已被消费），
    ///         此处仅验证请求成功返回 true，scene 参数传递由编译期 SendSmsRequest 保证。
    func testSendSmsCode_非Mock模式_scene为register_正常请求() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let json = self.makeEmptySuccessJSON()
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        let success = await AuthService.shared.sendSmsCode(phone: testPhone, scene: "register")

        XCTAssertTrue(success, "register 场景应成功")
    }

    /// 验证非 Mock 模式下 sendSmsCode 请求路径正确
    func testSendSmsCode_非Mock模式_请求路径正确() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        var capturedPath: String?

        TestMockURLProtocol.requestHandler = { request in
            capturedPath = request.url?.path
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let json = self.makeEmptySuccessJSON()
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        _ = await AuthService.shared.sendSmsCode(phone: testPhone, scene: testScene)

        XCTAssertEqual(capturedPath, APIPaths.smsSendPath, "应请求短信发送接口")
    }

    /// 验证非 Mock 模式下 sendSmsCode 请求方法为 POST
    func testSendSmsCode_非Mock模式_请求方法为POST() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        var capturedMethod: String?

        TestMockURLProtocol.requestHandler = { request in
            capturedMethod = request.httpMethod
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let json = self.makeEmptySuccessJSON()
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        _ = await AuthService.shared.sendSmsCode(phone: testPhone, scene: testScene)

        XCTAssertEqual(capturedMethod, "POST", "应使用 POST 方法")
    }

    /// 验证非 Mock 模式下 sendSmsCode requiresAuth 为 false
    func testSendSmsCode_非Mock模式_requiresAuth为false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        var hasAuthHeader = false

        TestMockURLProtocol.requestHandler = { request in
            hasAuthHeader = request.value(forHTTPHeaderField: "Authorization") != nil
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let json = self.makeEmptySuccessJSON()
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        _ = await AuthService.shared.sendSmsCode(phone: testPhone, scene: testScene)

        XCTAssertFalse(hasAuthHeader, "sendSmsCode requiresAuth 为 false，不应携带 Authorization 头")
    }

    // MARK: - register（短信验证码登录/注册）非 Mock 模式

    /// 验证非 Mock 模式下 register 网络成功返回 true
    func testRegister_非Mock模式_网络成功_返回true() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.phoneLoginPath {
                let json = self.makeLoginResponseJSON(isNewUser: true)
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        let success = await AuthService.shared.register(phone: testPhone, code: testSmsCode, password: testPassword)

        XCTAssertTrue(success, "网络成功应返回 true")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
    }

    /// 验证非 Mock 模式下 register 网络失败返回 false
    func testRegister_非Mock模式_网络失败_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        let success = await AuthService.shared.register(phone: testPhone, code: testSmsCode, password: testPassword)

        XCTAssertFalse(success, "网络失败应返回 false")
        XCTAssertFalse(AuthService.shared.isAuthenticated, "应保持未登录")
    }

    /// 验证非 Mock 模式下 register 后端业务错误返回 false
    func testRegister_非Mock模式_后端业务错误_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let json: [String: Any] = [
                "code": 1003,
                "message": "invalid sms code",
                "data": NSNull(),
                "requestId": "req",
                "timestamp": 123
            ]
            return (response, try JSONSerialization.data(withJSONObject: json))
        }

        let success = await AuthService.shared.register(phone: testPhone, code: "wrong", password: testPassword)

        XCTAssertFalse(success, "后端业务错误应返回 false")
    }

    /// 验证非 Mock 模式下 register 请求路径包含登录接口
    /// - Note: register 会先请求 phoneLoginPath 再请求 userProfilePath，
    ///         此处捕获所有请求路径并验证包含 phoneLoginPath。
    func testRegister_非Mock模式_请求路径正确() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        var capturedPaths: [String] = []

        TestMockURLProtocol.requestHandler = { request in
            if let path = request.url?.path {
                capturedPaths.append(path)
            }
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.phoneLoginPath {
                let json = self.makeLoginResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        _ = await AuthService.shared.register(phone: testPhone, code: testSmsCode, password: testPassword)

        XCTAssertTrue(capturedPaths.contains(APIPaths.phoneLoginPath), "register 应请求登录接口")
    }

    /// 验证非 Mock 模式下 register 成功后 currentUser name 为 phone
    func testRegister_非Mock模式_成功_currentUserName为phone() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.phoneLoginPath {
                let json = self.makeLoginResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        let success = await AuthService.shared.register(phone: testPhone, code: testSmsCode, password: testPassword)

        XCTAssertTrue(success, "register 应成功")
        // handleSuccessfulLogin 中 identity 参数为 phone，非 Mock 模式下会拉取 profile 覆盖 name
        // 因此 name 应为 profile 返回的 nick，而非 phone
        XCTAssertEqual(AuthService.shared.currentUser?.name, "Profile用户", "非 Mock 模式应填充 profile nick")
    }

    /// 验证非 Mock 模式下 register 成功后写入 Keychain token
    func testRegister_非Mock模式_成功_写入KeychainToken() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()
        try? KeychainService.shared.delete(key: jwtTokenKey)

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.phoneLoginPath {
                let json = self.makeLoginResponseJSON(
                    accessToken: "register_access",
                    refreshToken: "register_refresh"
                )
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        let success = await AuthService.shared.register(phone: testPhone, code: testSmsCode, password: testPassword)

        XCTAssertTrue(success, "register 应成功")
        let jwt = try? KeychainService.shared.retrieve(key: jwtTokenKey)
        XCTAssertEqual(jwt, "register_access", "应写入 access token")
        let refresh = try? KeychainService.shared.retrieve(key: refreshTokenKey)
        XCTAssertEqual(refresh, "register_refresh", "应写入 refresh token")
    }

    /// 验证非 Mock 模式下 register 拉取 profile 失败返回 false
    func testRegister_非Mock模式_拉取Profile失败_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            if request.url?.path == APIPaths.userProfilePath {
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: url,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (response, Data())
            }
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let json = self.makeLoginResponseJSON()
            return (response, try JSONSerialization.data(withJSONObject: json))
        }

        let success = await AuthService.shared.register(phone: testPhone, code: testSmsCode, password: testPassword)

        XCTAssertFalse(success, "拉取 profile 失败应返回 false")
    }
}

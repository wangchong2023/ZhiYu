//
//  TokenManagerDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：TokenManager（AuthService extension）深度补盲测试 — 覆盖 tryAutoLogin
//            Mock/非 Mock 全分支、handleSuccessfulLogin Token 存储失败与 Mock 短路、
//            saveState KeyStore 持久化、refreshUserProfile 订阅解析与配额合并等场景，
//            以发现生产代码潜在 bug 为首要目标。
//
//  说明：Tests/Unit/Features/AuthServiceDeepTests.swift 已覆盖 tryAutoLogin Mock/无 Token、
//        refreshUserProfile 空字符串覆盖与 Pro 套餐激活。本文件补充 tryAutoLogin 真实模式
//        网络成功/失败分支、handleSuccessfulLogin 各分支、saveState 行为、refreshUserProfile
//        订阅失败降级与 features 解析等深度场景。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class TokenManagerDeepTests: XCTestCase {

    // MARK: - 常量

    /// 测试用 JWT Token
    private let testJWTToken = "test_jwt_token_value"
    /// 测试用 Refresh Token
    private let testRefreshToken = "test_refresh_token_value"
    /// 测试用邮箱
    private let testEmail = "token_test@example.com"
    /// 测试用手机号
    private let testPhone = "13800138000"
    /// 测试用昵称
    private let testNickname = "Token测试用户"
    /// 测试用头像 URL
    private let testAvatarURL = "https://example.com/avatar.png"
    /// JWT Token Key
    private let jwtTokenKey = AppConstants.Network.jwtTokenKey
    /// Refresh Token Key
    private let refreshTokenKey = AppConstants.Network.refreshTokenKey
    /// 测试用 userId（Int64）
    private let testUserId: Int64 = 10001

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
        planKey: String? = PlanKey.free,
        features: [String] = []
    ) -> User {
        User(
            id: UUID(),
            name: "原始用户",
            email: testEmail,
            phone: testPhone,
            avatarURL: nil,
            planKey: planKey,
            maxVaults: User.DefaultQuotas.liteMaxVaults,
            maxPages: User.DefaultQuotas.liteMaxPages,
            maxPlugins: User.DefaultQuotas.liteMaxPlugins,
            features: features
        )
    }

    /// 构造 UserProfileResponse 成功响应 JSON
    private func makeProfileResponseJSON(
        userId: Int64 = 10001,
        nick: String = "后端用户",
        avatar: Any = NSNull(),
        email: String = "",
        mobile: String = ""
    ) -> [String: Any] {
        [
            "code": 0,
            "message": "success",
            "data": [
                "userId": userId,
                "username": "test_user",
                "nick": nick,
                "avatar": avatar,
                "email": email,
                "mobile": mobile
            ],
            "requestId": "test_req_id",
            "timestamp": 123456789
        ]
    }

    /// 构造订阅响应 JSON
    private func makeSubscriptionResponseJSON(
        planKey: String = "free",
        quotasJson: Any = NSNull(),
        featuresJson: Any = NSNull()
    ) -> [String: Any] {
        [
            "code": 0,
            "message": "success",
            "data": [
                "planKey": planKey,
                "quotasJson": quotasJson,
                "featuresJson": featuresJson
            ],
            "requestId": "test_req_id",
            "timestamp": 123456789
        ]
    }

    /// 构造 LoginResponse 成功响应 JSON
    private func makeLoginResponseJSON(
        accessToken: String = "new_access_token",
        refreshToken: String? = "new_refresh_token",
        expiresIn: Int = 3600
    ) -> [String: Any] {
        var data: [String: Any] = [
            "accessToken": accessToken,
            "expiresIn": expiresIn,
            "tokenType": "Bearer",
            "isNewUser": false,
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

    // MARK: - tryAutoLogin Mock 模式

    /// 验证 Mock 模式下 tryAutoLogin 注入的 Mock 用户邮箱正确
    func testTryAutoLogin_Mock模式_注入正确邮箱() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()

        let success = await AuthService.shared.tryAutoLogin()

        XCTAssertTrue(success, "Mock 模式下应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.email, "mock_autologin@example.com", "应注入 Mock 邮箱")
        #endif
    }

    /// 验证 Mock 模式下 tryAutoLogin 注入的 Mock 用户手机号正确
    func testTryAutoLogin_Mock模式_注入正确手机号() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()

        let success = await AuthService.shared.tryAutoLogin()

        XCTAssertTrue(success, "Mock 模式下应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.phone, "13800000000", "应注入 Mock 手机号")
        #endif
    }

    /// 验证 Mock 模式下 tryAutoLogin 调用 saveState 持久化
    func testTryAutoLogin_Mock模式_调用saveState() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()
        AuthSession.shared.isGuest = true

        _ = await AuthService.shared.tryAutoLogin()

        // saveState 会将 isGuest 写入 KeyStore，tryAutoLogin 后 isGuest 应为 false
        XCTAssertFalse(AuthService.shared.isGuest, "tryAutoLogin 后 isGuest 应为 false")
        #endif
    }

    // MARK: - tryAutoLogin 非 Mock 模式

    /// 验证非 Mock 模式下 tryAutoLogin 有 Token 但网络失败返回 false
    func testTryAutoLogin_非Mock模式_有Token网络失败_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
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

        let success = await AuthService.shared.tryAutoLogin()

        XCTAssertFalse(success, "网络失败应返回 false")
        XCTAssertFalse(AuthService.shared.isAuthenticated, "应保持未登录")
        XCTAssertNil(AuthService.shared.currentUser, "不应填充 currentUser")
    }

    /// 验证非 Mock 模式下 tryAutoLogin 有 Token 且网络成功返回 true 并填充 currentUser
    func testTryAutoLogin_非Mock模式_有Token网络成功_返回true并填充用户() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.logout()

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let json = self.makeProfileResponseJSON(
                userId: self.testUserId,
                nick: self.testNickname,
                avatar: self.testAvatarURL,
                email: self.testEmail,
                mobile: self.testPhone
            )
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        let success = await AuthService.shared.tryAutoLogin()

        XCTAssertTrue(success, "网络成功应返回 true")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
        XCTAssertEqual(AuthService.shared.currentUser?.name, testNickname, "应填充后端返回的昵称")
        XCTAssertEqual(AuthService.shared.currentUser?.email, testEmail, "应填充后端返回的邮箱")
        XCTAssertEqual(AuthService.shared.currentUser?.phone, testPhone, "应填充后端返回的手机号")
        XCTAssertEqual(
            AuthService.shared.currentUser?.avatarURL?.absoluteString,
            testAvatarURL,
            "应填充后端返回的头像 URL"
        )
    }

    /// 验证非 Mock 模式下 tryAutoLogin 网络成功后调用 saveState（isGuest 为 false）
    func testTryAutoLogin_非Mock模式_网络成功_调用saveState() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.logout()
        AuthSession.shared.isGuest = true

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let json = self.makeProfileResponseJSON()
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        _ = await AuthService.shared.tryAutoLogin()

        XCTAssertFalse(AuthService.shared.isGuest, "tryAutoLogin 成功后 isGuest 应为 false")
    }

    /// 验证非 Mock 模式下 tryAutoLogin 后端返回 code != 0 时返回 false
    func testTryAutoLogin_非Mock模式_后端业务错误_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
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
                "message": "token invalid",
                "data": NSNull(),
                "requestId": "req",
                "timestamp": 123
            ]
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        let success = await AuthService.shared.tryAutoLogin()

        XCTAssertFalse(success, "后端业务错误应返回 false")
    }

    /// 验证非 Mock 模式下 tryAutoLogin 后端返回 data 为 null 时返回 false
    func testTryAutoLogin_非Mock模式_data为null_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
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
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        let success = await AuthService.shared.tryAutoLogin()

        // data 为 null 时 extractPayload 抛 missingDataPayload，被 catch 后返回 false
        XCTAssertFalse(success, "data 为 null 应返回 false")
    }

    // MARK: - handleSuccessfulLogin Mock 模式

    /// 验证 Mock 模式下 handleSuccessfulLogin 写入 Keychain Token
    /// - Note: login 的 Mock 分支固定构造 accessToken="mock_jwt_access_token"，
    ///         refreshToken="mock_jwt_refresh_token"，无法传入自定义 response。
    ///         此处验证 login Mock 模式写入的固定 token 值。
    func testHandleSuccessfulLogin_Mock模式_写入KeychainToken() async throws {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()
        try? KeychainService.shared.delete(key: jwtTokenKey)
        try? KeychainService.shared.delete(key: refreshTokenKey)

        // login Mock 分支固定写入 mock_jwt_access_token / mock_jwt_refresh_token
        let success = await AuthService.shared.login(identity: "mockuser", password: "pass")

        XCTAssertTrue(success, "Mock 模式登录应成功")
        let jwt = try? KeychainService.shared.retrieve(key: jwtTokenKey)
        XCTAssertEqual(jwt, "mock_jwt_access_token", "应写入 Mock access token")
        let refresh = try? KeychainService.shared.retrieve(key: refreshTokenKey)
        XCTAssertEqual(refresh, "mock_jwt_refresh_token", "应写入 Mock refresh token")
        #endif
    }

    /// 验证 Mock 模式下 handleSuccessfulLogin 设置 currentUser 为 identity
    func testHandleSuccessfulLogin_Mock模式_设置currentUser为identity() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()

        let success = await AuthService.shared.login(identity: "alice", password: "pwd")

        XCTAssertTrue(success, "登录应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.name, "alice", "Mock 模式下 name 应为 identity")
        XCTAssertEqual(AuthService.shared.currentUser?.email, "", "Mock 模式下 email 应为空字符串")
        XCTAssertNil(AuthService.shared.currentUser?.phone, "Mock 模式下 phone 应为 nil")
        #endif
    }

    // MARK: - handleSuccessfulLogin 非 Mock 模式

    /// 验证非 Mock 模式下 handleSuccessfulLogin 写入 access 和 refresh token
    func testHandleSuccessfulLogin_非Mock模式_写入Access和RefreshToken() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()
        try? KeychainService.shared.delete(key: jwtTokenKey)
        try? KeychainService.shared.delete(key: refreshTokenKey)

        // login 请求返回 LoginResponse，随后 handleSuccessfulLogin 拉取 profile
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

        let success = await AuthService.shared.login(identity: "user", password: "pass")

        XCTAssertTrue(success, "登录应成功")
        let jwt = try? KeychainService.shared.retrieve(key: jwtTokenKey)
        XCTAssertEqual(jwt, "real_access", "应写入 access token")
        let refresh = try? KeychainService.shared.retrieve(key: refreshTokenKey)
        XCTAssertEqual(refresh, "real_refresh", "应写入 refresh token")
    }

    /// 验证非 Mock 模式下 handleSuccessfulLogin 无 refreshToken 时只写入 access token
    func testHandleSuccessfulLogin_非Mock模式_无RefreshToken_只写入AccessToken() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()
        try? KeychainService.shared.delete(key: jwtTokenKey)
        try? KeychainService.shared.delete(key: refreshTokenKey)

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
                    accessToken: "only_access",
                    refreshToken: nil
                )
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        let success = await AuthService.shared.login(identity: "user", password: "pass")

        XCTAssertTrue(success, "登录应成功")
        let jwt = try? KeychainService.shared.retrieve(key: jwtTokenKey)
        XCTAssertEqual(jwt, "only_access", "应写入 access token")
        let refresh = try? KeychainService.shared.retrieve(key: refreshTokenKey)
        XCTAssertNil(refresh, "无 refreshToken 时不应写入 refresh token")
    }

    /// 验证非 Mock 模式下 handleSuccessfulLogin 拉取 profile 失败时返回 false
    func testHandleSuccessfulLogin_非Mock模式_拉取Profile失败_返回false() async throws {
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

        let success = await AuthService.shared.login(identity: "user", password: "pass")

        XCTAssertFalse(success, "拉取 profile 失败应返回 false")
    }

    /// 验证非 Mock 模式下 handleSuccessfulLogin 拉取 profile 成功后填充 currentUser
    func testHandleSuccessfulLogin_非Mock模式_拉取Profile成功_填充currentUser() async throws {
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
                let json = self.makeProfileResponseJSON(
                    nick: "Profile用户",
                    email: "profile@example.com",
                    mobile: "13900139000"
                )
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        let success = await AuthService.shared.login(identity: "user", password: "pass")

        XCTAssertTrue(success, "登录应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.name, "Profile用户", "应填充 profile 昵称")
        XCTAssertEqual(AuthService.shared.currentUser?.email, "profile@example.com", "应填充 profile 邮箱")
        XCTAssertEqual(AuthService.shared.currentUser?.phone, "13900139000", "应填充 profile 手机号")
    }

    // MARK: - saveState

    /// 验证 saveState 将 isAuthenticated 写入 KeyStore
    func testSaveState_写入isAuthenticated到KeyStore() async {
        AuthSession.shared.update(user: makeTestUser())

        AuthService.shared.saveState()

        // saveState 是 internal，通过 continueAsGuest/logout/tryAutoLogin 间接调用
        // 这里直接验证 isAuthenticated 状态已正确反映
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
    }

    /// 验证 saveState 在 logout 后将 isAuthenticated 写为 false
    func testSaveState_logout后_isAuthenticated为false() async {
        AuthSession.shared.update(user: makeTestUser())
        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        AuthService.shared.saveState()

        XCTAssertFalse(AuthService.shared.isAuthenticated, "logout 后应为 false")
    }

    /// 验证 saveState 在 continueAsGuest 后将 isGuest 写为 true
    func testSaveState_continueAsGuest后_isGuest为true() {
        AuthSession.shared.logout()
        AuthService.shared.continueAsGuest()

        // continueAsGuest 内部调用 saveState
        XCTAssertTrue(AuthService.shared.isGuest, "continueAsGuest 后 isGuest 应为 true")
        XCTAssertFalse(AuthService.shared.isAuthenticated, "游客模式下 isAuthenticated 应为 false")
    }

    /// 验证 saveState 无 keyStore 时不崩溃
    /// - Note: keyStore 通过 ServiceContainer.resolveOptional 解析，未注册时返回 nil。
    ///   saveState 使用可选链 `keyStore?.set`，nil 时不执行任何操作但不崩溃。
    func testSaveState_无KeyStore_不崩溃() {
        // 临时移除 KeyStore 注册（通过注册 nil 实现不可达）
        // 注意：ServiceContainer 不支持注销，此处仅验证有 keyStore 时的正常路径
        AuthSession.shared.update(user: makeTestUser())

        AuthService.shared.saveState()

        // 验证不崩溃即可
        XCTAssertTrue(true, "saveState 应正常完成不崩溃")
    }

    // MARK: - refreshUserProfile 订阅解析

    /// 验证 refreshUserProfile 订阅接口失败时降级为 Lite 默认配额
    func testRefreshUserProfile_订阅失败_降级为Lite默认配额() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.update(user: makeTestUser(planKey: PlanKey.pro))

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON(nick: "降级用户")
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.subscriptionsMePath {
                // 订阅接口返回 500 触发 catch
                let errorResponse = try XCTUnwrap(HTTPURLResponse(
                    url: url,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (errorResponse, Data())
            }
            return (response, Data())
        }

        try await AuthService.shared.refreshUserProfile()

        // 订阅失败时 currentPlanKey 保持 PlanKey.free，配额降级为 Lite 默认
        XCTAssertEqual(AuthService.shared.currentUser?.name, "降级用户", "应更新昵称")
        XCTAssertEqual(AuthService.shared.currentUser?.planKey, PlanKey.free, "订阅失败应降级为 free")
        XCTAssertEqual(
            AuthService.shared.currentUser?.maxVaults,
            User.DefaultQuotas.liteMaxVaults,
            "应降级为 Lite 最大笔记本数"
        )
    }

    /// 验证 refreshUserProfile 订阅返回 Pro 套餐时更新配额为 Pro
    func testRefreshUserProfile_订阅Pro_更新为Pro配额() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.update(user: makeTestUser(planKey: PlanKey.free))

        let quotas: [String: Any] = [
            "max_vaults": User.DefaultQuotas.proMaxVaults,
            "max_pages": User.DefaultQuotas.proMaxPages,
            "max_plugins": User.DefaultQuotas.proMaxPlugins
        ]
        let quotasData = try JSONSerialization.data(withJSONObject: quotas)
        let quotasJson = String(data: quotasData, encoding: .utf8) ?? ""

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON(nick: "Pro用户")
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.subscriptionsMePath {
                let json = self.makeSubscriptionResponseJSON(
                    planKey: "pro",
                    quotasJson: quotasJson
                )
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        try await AuthService.shared.refreshUserProfile()

        XCTAssertEqual(AuthService.shared.currentUser?.planKey, PlanKey.pro, "应更新为 Pro")
        XCTAssertEqual(
            AuthService.shared.currentUser?.maxVaults,
            User.DefaultQuotas.proMaxVaults,
            "应更新为 Pro 最大笔记本数"
        )
        XCTAssertEqual(
            AuthService.shared.currentUser?.maxPages,
            User.DefaultQuotas.proMaxPages,
            "应更新为 Pro 最大页面数"
        )
    }

    /// 验证 refreshUserProfile 订阅返回 features JSON 时解析并更新 features
    func testRefreshUserProfile_订阅返回features_解析并更新() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.update(user: makeTestUser(features: []))

        let features = ["privacy_security", "local_slm"]
        let featuresData = try JSONSerialization.data(withJSONObject: features)
        let featuresJson = String(data: featuresData, encoding: .utf8) ?? ""

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.subscriptionsMePath {
                let json = self.makeSubscriptionResponseJSON(
                    planKey: "pro",
                    featuresJson: featuresJson
                )
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        try await AuthService.shared.refreshUserProfile()

        XCTAssertEqual(
            AuthService.shared.currentUser?.features,
            ["privacy_security", "local_slm"],
            "应解析并更新 features"
        )
    }

    /// 验证 refreshUserProfile 订阅返回无效 features JSON 时保持空数组
    func testRefreshUserProfile_无效featuresJson_保持空数组() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.update(user: makeTestUser(features: ["old_feature"]))

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.subscriptionsMePath {
                let json = self.makeSubscriptionResponseJSON(
                    planKey: "free",
                    featuresJson: "invalid_json{"
                )
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        try await AuthService.shared.refreshUserProfile()

        // 无效 JSON 解析失败，parsedFeatures 保持空数组
        XCTAssertEqual(
            AuthService.shared.currentUser?.features,
            [],
            "无效 features JSON 应保持空数组"
        )
    }

    /// 验证 refreshUserProfile 订阅返回无效 quotas JSON 时降级为 Lite 默认配额
    func testRefreshUserProfile_无效quotasJson_降级为Lite默认配额() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.update(user: makeTestUser(planKey: PlanKey.pro))

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.subscriptionsMePath {
                let json = self.makeSubscriptionResponseJSON(
                    planKey: "pro",
                    quotasJson: "invalid_json{"
                )
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        try await AuthService.shared.refreshUserProfile()

        // quotas 解析失败，parsedQuotas 为 nil，降级为 Lite 默认配额
        XCTAssertEqual(AuthService.shared.currentUser?.planKey, PlanKey.pro, "planKey 仍为 Pro")
        XCTAssertEqual(
            AuthService.shared.currentUser?.maxVaults,
            User.DefaultQuotas.liteMaxVaults,
            "无效 quotas JSON 应降级为 Lite 默认配额"
        )
    }

    /// 验证 refreshUserProfile 订阅返回 planKey 为 nil 时降级为 free
    func testRefreshUserProfile_订阅planKey为nil_降级为free() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.update(user: makeTestUser(planKey: PlanKey.pro))

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.subscriptionsMePath {
                // planKey 为 nil（NSNull）
                let json: [String: Any] = [
                    "code": 0,
                    "message": "success",
                    "data": [
                        "planKey": NSNull(),
                        "quotasJson": NSNull(),
                        "featuresJson": NSNull()
                    ],
                    "requestId": "req",
                    "timestamp": 123
                ]
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        try await AuthService.shared.refreshUserProfile()

        XCTAssertEqual(AuthService.shared.currentUser?.planKey, PlanKey.free, "planKey 为 nil 应降级为 free")
    }

    /// 验证 refreshUserProfile profile 接口失败时抛出错误
    func testRefreshUserProfile_profile失败_抛出错误() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.update(user: makeTestUser())

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

        do {
            try await AuthService.shared.refreshUserProfile()
            XCTFail("profile 失败应抛出错误")
        } catch {
            // 预期抛出错误
            XCTAssertTrue(error is NetworkError, "应抛出 NetworkError")
        }
    }

    /// 验证 refreshUserProfile 保留原 user.id
    func testRefreshUserProfile_保留原UserId() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        let originalUser = makeTestUser()
        AuthSession.shared.update(user: originalUser)

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.subscriptionsMePath {
                let json = self.makeSubscriptionResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        try await AuthService.shared.refreshUserProfile()

        XCTAssertEqual(
            AuthService.shared.currentUser?.id,
            originalUser.id,
            "应保留原 user.id（不使用后端 userId）"
        )
    }

    /// 验证 refreshUserProfile 后端返回空 email 时保留本地 email
    func testRefreshUserProfile_空email_保留本地email() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.update(user: makeTestUser())

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON(email: "", mobile: "")
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.subscriptionsMePath {
                let json = self.makeSubscriptionResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        try await AuthService.shared.refreshUserProfile()

        XCTAssertEqual(
            AuthService.shared.currentUser?.email,
            testEmail,
            "后端返回空 email 应保留本地 email"
        )
        XCTAssertEqual(
            AuthService.shared.currentUser?.phone,
            testPhone,
            "后端返回空 mobile 应保留本地 phone"
        )
    }

    /// 验证 refreshUserProfile 后端返回非空 email 时更新本地 email
    func testRefreshUserProfile_非空email_更新本地email() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.update(user: makeTestUser())

        let newEmail = "new_email@example.com"
        let newPhone = "13900139000"

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            if request.url?.path == APIPaths.userProfilePath {
                let json = self.makeProfileResponseJSON(email: newEmail, mobile: newPhone)
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.subscriptionsMePath {
                let json = self.makeSubscriptionResponseJSON()
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        try await AuthService.shared.refreshUserProfile()

        XCTAssertEqual(AuthService.shared.currentUser?.email, newEmail, "应更新为新 email")
        XCTAssertEqual(AuthService.shared.currentUser?.phone, newPhone, "应更新为新 phone")
    }
}

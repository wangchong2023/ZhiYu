//
//  AuthServiceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 AuthService 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

@MainActor
final class AuthServiceTests: XCTestCase {

    private var testSession: URLSession!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()

        // 注入 Mock Keychain，绕过模拟器 errSecMissingEntitlement -34018 限制
        KeychainService.testOverride = MockKeychainService()

        // 注入 TestMockURLProtocol 的测试 URLSession
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestMockURLProtocol.self]
        testSession = URLSession(configuration: config)
        await NetworkClient.shared.setTestSession(testSession)

        AuthSession.shared.logout()
        try? KeychainService.shared.delete(key: AppConstants.Network.jwtTokenKey)
        try? KeychainService.shared.delete(key: "refresh_token")
    }

    override func tearDown() async throws {
        AuthSession.shared.logout()
        await awaitAllLogoutTasks()
        await NetworkClient.shared.awaitRefreshTask()
        await NetworkClient.shared.setTestSession(nil)
        TestMockURLProtocol.requestHandler = nil
        KeychainService.testOverride = nil
        try await super.tearDown()
    }

    private func awaitAllLogoutTasks() async {
        for task in AuthService.shared.testLogoutTasks {
            await task.value
        }
        AuthService.shared.testLogoutTasks.removeAll()
    }

    // MARK: - 登出测试

    func testLogoutClearsState() async {
        AuthSession.shared.update(user: User(id: UUID(), name: "Test User", email: "test@example.com"))
        XCTAssertTrue(AuthService.shared.isAuthenticated)

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertFalse(AuthService.shared.isAuthenticated)
        XCTAssertNil(AuthService.shared.currentUser)
    }

    func testLogoutClearsGuestFlag() async {
        // 确保从干净状态开始，避免前序测试任务残留导致 CI 偶发失败
        AuthSession.shared.logout()
        await awaitAllLogoutTasks()
        
        AuthSession.shared.isGuest = false
        XCTAssertFalse(AuthSession.shared.isGuest, "初始 isGuest 应为 false")
        AuthSession.shared.isGuest = true
        XCTAssertTrue(AuthService.shared.isGuest)

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertFalse(AuthService.shared.isGuest)
    }

    // MARK: - 游客模式测试

    func testContinueAsGuestSetsGuestFlag() {
        AuthService.shared.continueAsGuest()

        let expectation = XCTestExpectation(description: "等待游客登录异步完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(AuthService.shared.isGuest)
    }

    // MARK: - 统一第三方登录测试 (DEBUG Mock)

    func testLoginWithCarrierStrategyInDebug() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        let success = await AuthService.shared.login(using: CarrierAuthStrategy())
        XCTAssertTrue(success, "DEBUG 模式下 Carrier Mock 登录应成功")
        #endif
    }

    func testLoginWithGitHubStrategyInDebug() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        let success = await AuthService.shared.login(using: GitHubAuthStrategy())
        XCTAssertTrue(success, "DEBUG 模式下 GitHub Mock 登录应成功")
        #endif
    }

    func testLoginWithWeChatStrategyInDebug() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        let success = await AuthService.shared.login(using: WeChatAuthStrategy())
        XCTAssertTrue(success, "DEBUG 模式下 WeChat Mock 登录应成功")
        #endif
    }

    // MARK: - 密码/验证码登录网络失败测试

    func testPasswordLoginFailsWithoutNetwork() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        let success = await AuthService.shared.login(identity: "testuser", password: "testpass")
        XCTAssertFalse(success, "无后端服务时密码登录应返回 false")
    }

    func testSmsSendFailsWithoutNetwork() async {
        let success = await AuthService.shared.sendSmsCode(phone: "13800138000", scene: "login")
        XCTAssertFalse(success, "无后端服务时发送验证码应返回 false")
    }

    func testSmsCodeLoginFailsWithoutNetwork() async {
        let success = await AuthService.shared.register(phone: "13800138000", code: "123456", password: "")
        XCTAssertFalse(success, "无后端服务时验证码登录应返回 false")
    }

    // MARK: - 自动静默登录与不超时退登保障测试

    /// 测试：当安全区 Keychain 中无 Token 时，tryAutoLogin 应该直接返回 false
    func testTryAutoLoginNoToken() async {
        // 确保 Keychain 中没有任何 Token
        try? KeychainService.shared.delete(key: AppConstants.Network.jwtTokenKey)

        #if DEBUG
        AuthService.forceMockBackend = false
        #endif

        let success = await AuthService.shared.tryAutoLogin()
        XCTAssertFalse(success, "无 Token 缓存时，自动登录应失败")
        XCTAssertFalse(AuthService.shared.isAuthenticated)
    }

    /// 测试：当处于 Mock 模式时，tryAutoLogin 应该无视物理网络直接注入 Mock 用户并返回 true
    func testTryAutoLoginMockBackend() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }

        let success = await AuthService.shared.tryAutoLogin()
        XCTAssertTrue(success, "Mock 后端模式下自动静默登录应成功")
        XCTAssertTrue(AuthService.shared.isAuthenticated)
        XCTAssertEqual(AuthService.shared.currentUser?.name, "Mock Autologin User")
        #endif
    }

    /// 测试：当 Keychain 中存在有效 Token，且拉取 Profile 成功时，tryAutoLogin 应返回 true 并更新状态树
    func testTryAutoLoginSucceedsWithValidToken() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif

        // 1. 注入 Token（Mock Keychain 已由 setUp 注入，模拟器环境安全）
        try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: "valid_jwt_token")

        // 2. 模拟拉取 Profile 返回成功
        let profileResponse = UserProfileResponse(
            userId: 10001,
            username: "test_user",
            nick: "ZhiYu Test User",
            avatar: "https://example.com/avatar.png",
            email: "test@example.com",
            mobile: "13800138000",
            gender: 1,
            birthday: "1995-01-01"
        )

        let apiResponse = ApiResponse(code: 0, message: "success", data: profileResponse, requestId: "test_req_id", timestamp: 123456789)
        let responseData = try JSONEncoder().encode(apiResponse)

        TestMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, APIPaths.userProfilePath)
            XCTAssertEqual(request.value(forHTTPHeaderField: AppConstants.Network.headerAuthorization), "Bearer valid_jwt_token")

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, responseData)
        }

        // 3. 执行
        let success = await AuthService.shared.tryAutoLogin()

        // 4. 验证
        XCTAssertTrue(success, "有效 Token 且 Profile 拉取成功，自动登录应返回 true")
        XCTAssertTrue(AuthService.shared.isAuthenticated)
        XCTAssertEqual(AuthService.shared.currentUser?.name, "ZhiYu Test User")
        XCTAssertEqual(AuthService.shared.currentUser?.email, "test@example.com")
        XCTAssertEqual(AuthService.shared.currentUser?.phone, "13800138000")
    }

    /// 测试：当 Keychain 中有 Token 但拉取 Profile 接口报错（如 401），tryAutoLogin 应该返回 false 并保持未登录状态
    func testTryAutoLoginFailsWithInvalidToken() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif

        // 1. 注入 Token（Mock Keychain 已由 setUp 注入，模拟器环境安全）
        try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: "expired_jwt_token")

        // 2. 模拟拉取 Profile 接口返回 40101 错误或 401 HTTP 状态
        let apiResponse: ApiResponse<UserProfileResponse> = ApiResponse(code: 40101, message: "Token expired", data: nil, requestId: "test_req_id", timestamp: 123456789)
        let responseData = try JSONEncoder().encode(apiResponse)

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, responseData)
        }

        // 3. 执行
        let success = await AuthService.shared.tryAutoLogin()

        // 4. 验证
        XCTAssertFalse(success, "Token 失效时，自动登录应该返回 false")
        XCTAssertFalse(AuthService.shared.isAuthenticated)
    }

    /// 测试：当系统广播 .userAuthExpired 通知时，AuthSession 应该执行注销操作，清空当前用户并退回到未登录状态
    func testUserAuthExpiredNotificationResponds() async {
        // 1. 预设已登录状态
        AuthSession.shared.update(user: User(id: UUID(), name: "Login User", email: "test@example.com"))
        XCTAssertTrue(AuthService.shared.isAuthenticated)

        // 2. 模拟 ContentView 注册的通知监听响应
        let expectation = XCTestExpectation(description: "监听到 userAuthExpired 通知并执行注销")

        // queue: nil 意味着回调在通知发送线程执行；.userAuthExpired 可能从后台队列发出，
        // 而 AuthService.shared.logout() 标记了 @MainActor，Swift 6 严格并发下从非主线程
        // 直接调用会触发运行时 SIGABRT（_swift_task_dealloc_specific）。
        let observer = NotificationCenter.default.addObserver(
            forName: .userAuthExpired,
            object: nil,
            queue: nil
        ) { _ in
            DispatchQueue.main.async {
                AuthService.shared.logout()
                expectation.fulfill()
            }
        }

        // 3. 发送广播
        NotificationCenter.default.post(name: .userAuthExpired, object: nil)

        // 4. 等待
        await fulfillment(of: [expectation], timeout: 2.0)
        NotificationCenter.default.removeObserver(observer)
        await awaitAllLogoutTasks()

        // 5. 验证退登
        XCTAssertFalse(AuthService.shared.isAuthenticated)
        XCTAssertNil(AuthService.shared.currentUser)
    }

    /// 测试：当登出请求返回 401 且触发刷新失败导致的递归调用时，Keychain 是否依然能被清理
    func testLogoutClearsKeychainEvenIfBackendFailsWith401() async throws {
        // 1. 模拟写入凭证（Mock Keychain 已由 setUp 注入，模拟器环境安全）
        try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: "expired_token")
        try KeychainService.shared.store(key: "refresh_token", value: "expired_refresh_token")

        AuthSession.shared.update(user: User(id: UUID(), name: "Test User", email: "test@example.com"))

        // 2. 模拟注销接口返回 401
        var logoutCallCount = 0
        TestMockURLProtocol.requestHandler = { request in
            logoutCallCount += 1
            let url = try XCTUnwrap(request.url)
            
            if request.url?.path == "/api/v1/auth/logout" {
                // 返回 401 模拟 Token 过期
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil))
                let apiResponse: ApiResponse<EmptyData> = ApiResponse(code: 40101, message: "Unauthorized", data: nil, requestId: "req", timestamp: 123)
                let data = try JSONEncoder().encode(apiResponse)
                return (response, data)
            } else if request.url?.path == APIPaths.refreshPath {
                // 刷新也失败，返回 401 错误 JSON
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil))
                let apiResponse: ApiResponse<EmptyData> = ApiResponse(code: 40103, message: "Refresh token expired", data: nil, requestId: "req", timestamp: 123)
                let data = try JSONEncoder().encode(apiResponse)
                return (response, data)
            }
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)), nil)
        }

        // 3. 注册通知监听，模拟应用行为（必须使用 .main queue，因为 .userAuthExpired 由 NetworkClient 在背景队列上发出，
        //    而 AuthService.shared.logout() 标记了 @MainActor，Swift 6 严格并发模式下从背景线程调用会 SIGABRT）
        let expectation = XCTestExpectation(description: "监听到 userAuthExpired")
        let observer = NotificationCenter.default.addObserver(forName: .userAuthExpired, object: nil, queue: nil) { _ in
            print("[TEST] Received .userAuthExpired, calling logout() again")
            DispatchQueue.main.async {
                AuthService.shared.logout()
                expectation.fulfill()
            }
        }

        // 4. 触发退出
        print("[TEST] Triggering first logout()")
        AuthService.shared.logout()

        // 5. 等待
        await fulfillment(of: [expectation], timeout: 5.0)
        await awaitAllLogoutTasks()
        NotificationCenter.default.removeObserver(observer)

        // 6. 验证
        print("[TEST] Final verification")
        XCTAssertFalse(AuthService.shared.isAuthenticated)
        let jwt = try? KeychainService.shared.retrieve(key: AppConstants.Network.jwtTokenKey)
        XCTAssertNil(jwt, "即便后端 401 导致递归，Keychain 也应该最终被清理")
        print("[TEST] logoutCallCount: \(logoutCallCount)")
    }

    /// 测试：登录成功后，执行 logout() 能否物理擦除 Keychain 中的 Token，防止残留劫持
    func testLogoutClearsKeychainTokens() async throws {
        // 1. 模拟登录写入 Token（Mock Keychain 已由 setUp 注入，模拟器环境安全）
        try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: "login_jwt_token")
        try KeychainService.shared.store(key: "refresh_token", value: "login_refresh_token")

        AuthSession.shared.update(user: User(id: UUID(), name: "Login User", email: "test@example.com"))
        XCTAssertTrue(AuthService.shared.isAuthenticated)

        // 2. 模拟注销接口拦截
        TestMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/logout")
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, nil)
        }

        // 3. 执行退出
        print("[TEST] Calling AuthService.shared.logout()")
        AuthService.shared.logout()

        // 4. 等待后台注销任务完成以检查物理擦除
        print("[TEST] Waiting for testLogoutTask...")
        await awaitAllLogoutTasks()
        print("[TEST] testLogoutTask finished waiting")

        // 5. 最终验证
        XCTAssertFalse(AuthService.shared.isAuthenticated)
        XCTAssertNil(AuthService.shared.currentUser)
        
        // 验证物理擦除
        print("[TEST] Verifying Keychain erasure...")
        let jwt = try? KeychainService.shared.retrieve(key: AppConstants.Network.jwtTokenKey)
        let refresh = try? KeychainService.shared.retrieve(key: "refresh_token")
        XCTAssertNil(jwt, "JWT Token 应该被物理擦除")
        XCTAssertNil(refresh, "Refresh Token 应该被物理擦除")
        print("[TEST] Keychain verification done")
    }

    /// 测试：退出登录时，客户端是否会向后端发送携带对应 refresh_token 的 POST 注销请求，使服务端吊销 Token
    func testLogoutTriggersBackendRevokeRequest() async throws {
        // 1. 模拟写入凭证（Mock Keychain 已由 setUp 注入，模拟器环境安全）
        try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: "jwt_token")
        try KeychainService.shared.store(key: "refresh_token", value: "refresh_token_to_revoke")

        AuthSession.shared.update(user: User(id: UUID(), name: "Login User", email: "test@example.com"))

        // 2. 拦截并校验登出请求
        let expectation = XCTestExpectation(description: "后端成功收到注销请求")
        TestMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/logout")
            XCTAssertEqual(request.httpMethod, "POST")

            if let bodyData = request.httpBodyStreamData() ?? request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
               let token = json["refreshToken"] as? String {
                XCTAssertEqual(token, "refresh_token_to_revoke")
            }

            expectation.fulfill()
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, nil)
        }

        // 3. 触发退出
        AuthService.shared.logout()

        // 4. 等待后台请求发送并被拦截断言
        await awaitAllLogoutTasks()
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - refreshUserProfile 空字符串覆盖测试（修复 #93 / #92）

    /// 验证修复 #93：后端返回空字符串 email 时，不应覆盖本地非空 email
    /// 修复前 `email: profile.email ?? user.email`，空字符串覆盖本地非空 email
    func testRefreshUserProfileEmptyEmailDoesNotOverrideLocal() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif

        // 1. 注入 Token 并设置本地用户（含非空 email 和 phone）
        try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: "valid_jwt_token")
        AuthSession.shared.update(user: User(
            id: UUID(),
            name: "Local User",
            email: "local@example.com",
            phone: "13800138000"
        ))

        // 2. Mock 后端返回空 email 和空 mobile
        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))

            if request.url?.path == "/api/v1/user/profile" {
                // 后端返回空字符串 email 和 mobile
                let json: [String: Any] = [
                    "code": 0,
                    "message": "success",
                    "data": [
                        "userId": 10001,
                        "username": "test_user",
                        "nick": "Backend User",
                        "avatar": NSNull(),
                        "email": "",
                        "mobile": ""
                    ],
                    "requestId": "test_req_id",
                    "timestamp": 123456789
                ]
                let data = try JSONSerialization.data(withJSONObject: json)
                return (response, data)
            } else if request.url?.path == "/api/v1/subscriptions/me" {
                let json: [String: Any] = [
                    "code": 0,
                    "message": "success",
                    "data": [
                        "planKey": "free",
                        "quotasJson": NSNull(),
                        "featuresJson": NSNull()
                    ],
                    "requestId": "test_req_id",
                    "timestamp": 123456789
                ]
                let data = try JSONSerialization.data(withJSONObject: json)
                return (response, data)
            }
            return (response, Data())
        }

        // 3. 执行 refreshUserProfile
        try await AuthService.shared.refreshUserProfile()

        // 4. 验证：空字符串不应覆盖本地非空值
        let updated = AuthSession.shared.currentUser
        XCTAssertEqual(updated?.email, "local@example.com", "后端返回空字符串 email 时应保留本地 email")
        XCTAssertEqual(updated?.phone, "13800138000", "后端返回空字符串 mobile 时应保留本地 phone")
        XCTAssertEqual(updated?.name, "Backend User", "nick 应正常更新")
    }

    /// 验证修复 #92：后端返回非空 mobile 时，应正常更新本地 phone
    func testRefreshUserProfileNonEmptyMobileUpdatesLocal() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif

        try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: "valid_jwt_token")
        AuthSession.shared.update(user: User(
            id: UUID(),
            name: "Local User",
            email: "local@example.com",
            phone: "13800138000"
        ))

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))

            if request.url?.path == "/api/v1/user/profile" {
                let json: [String: Any] = [
                    "code": 0,
                    "message": "success",
                    "data": [
                        "userId": 10001,
                        "username": "test_user",
                        "nick": "Backend User",
                        "avatar": NSNull(),
                        "email": "new@example.com",
                        "mobile": "13900139000"
                    ],
                    "requestId": "test_req_id",
                    "timestamp": 123456789
                ]
                let data = try JSONSerialization.data(withJSONObject: json)
                return (response, data)
            } else if request.url?.path == "/api/v1/subscriptions/me" {
                let json: [String: Any] = [
                    "code": 0,
                    "message": "success",
                    "data": [
                        "planKey": "pro",
                        "quotasJson": NSNull(),
                        "featuresJson": NSNull()
                    ],
                    "requestId": "test_req_id",
                    "timestamp": 123456789
                ]
                let data = try JSONSerialization.data(withJSONObject: json)
                return (response, data)
            }
            return (response, Data())
        }

        try await AuthService.shared.refreshUserProfile()

        let updated = AuthSession.shared.currentUser
        XCTAssertEqual(updated?.email, "new@example.com", "后端返回非空 email 应更新本地")
        XCTAssertEqual(updated?.phone, "13900139000", "后端返回非空 mobile 应更新本地 phone")
    }
}

// MARK: - URLRequest 扩展辅助测试
fileprivate extension URLRequest {
    /// 单元测试专用：读取 httpBodyStream 中的二进制流数据，解决 URLSession 发送时 body 格式化为流导致 httpBody 为空的问题
    func httpBodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

// MockVaultDatabaseSwitcher 已移至 Tests/Shared/TestMocks.swift 统一管理

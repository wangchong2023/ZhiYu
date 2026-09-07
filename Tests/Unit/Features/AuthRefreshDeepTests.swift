//
//  AuthRefreshDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AuthService 用户资料刷新深度测试 — 覆盖 refreshUserProfile 空字符串覆盖、
//            非空 avatar 更新、Pro 套餐配额更新、无当前用户不崩溃等场景，
//            以发现生产代码潜在 bug 为首要目标。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class AuthRefreshDeepTests: XCTestCase {

    // MARK: - 常量

    /// 测试用头像 URL
    private let testAvatarURL = "https://example.com/avatar.png"
    /// 测试用邮箱
    private let testEmail = "test@example.com"
    /// Pro 套餐最大笔记本数
    private let proMaxVaults = User.DefaultQuotas.proMaxVaults
    /// Pro 套餐最大页面数
    private let proMaxPages = User.DefaultQuotas.proMaxPages
    /// Lite 套餐最大笔记本数
    private let liteMaxVaults = User.DefaultQuotas.liteMaxVaults
    /// JWT Token Key
    private let jwtTokenKey = AppConstants.Network.jwtTokenKey
    /// 测试用 JWT Token 值
    private let testJWTToken = "test_jwt_token"

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

    // MARK: - refreshUserProfile 空字符串覆盖

    /// 验证 refreshUserProfile 后端返回空 avatar 时保留本地 avatar
    func testRefreshUserProfile_空avatar_保留本地avatar() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        var user = makeTestUser()
        user.avatarURL = URL(string: testAvatarURL)
        AuthSession.shared.update(user: user)

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))

            if request.url?.path == APIPaths.userProfilePath {
                let json: [String: Any] = [
                    "code": 0, "message": "success",
                    "data": [
                        "userId": 10001, "username": "test_user", "nick": "后端用户",
                        "avatar": NSNull(), "email": "", "mobile": ""
                    ],
                    "requestId": "req", "timestamp": 123
                ]
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.subscriptionsMePath {
                let json: [String: Any] = [
                    "code": 0, "message": "success",
                    "data": ["planKey": "free", "quotasJson": NSNull(), "featuresJson": NSNull()],
                    "requestId": "req", "timestamp": 123
                ]
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        try await AuthService.shared.refreshUserProfile()

        // C-20 修复后：avatar 空时保留本地值（与 email/phone 策略一致）
        XCTAssertEqual(AuthService.shared.currentUser?.avatarURL?.absoluteString, testAvatarURL, "后端返回空 avatar 时应保留本地 avatar（C-20 修复）")
    }

    /// 验证 refreshUserProfile 后端返回非空 avatar 时更新本地 avatar
    func testRefreshUserProfile_非空avatar_更新本地avatar() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.update(user: makeTestUser())

        let newAvatar = "https://example.com/new_avatar.png"
        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))

            if request.url?.path == APIPaths.userProfilePath {
                let json: [String: Any] = [
                    "code": 0, "message": "success",
                    "data": [
                        "userId": 10001, "username": "test_user", "nick": "后端用户",
                        "avatar": newAvatar, "email": "new@example.com", "mobile": "13900139000"
                    ],
                    "requestId": "req", "timestamp": 123
                ]
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.subscriptionsMePath {
                let json: [String: Any] = [
                    "code": 0, "message": "success",
                    "data": ["planKey": "pro", "quotasJson": NSNull(), "featuresJson": NSNull()],
                    "requestId": "req", "timestamp": 123
                ]
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        try await AuthService.shared.refreshUserProfile()

        XCTAssertEqual(AuthService.shared.currentUser?.avatarURL?.absoluteString, newAvatar, "应更新为新 avatar URL")
    }

    /// 验证 refreshUserProfile 后端返回 Pro 套餐时更新配额
    func testRefreshUserProfile_Pro套餐_更新配额() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.update(user: makeTestUser(planKey: PlanKey.free))

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))

            if request.url?.path == APIPaths.userProfilePath {
                let json: [String: Any] = [
                    "code": 0, "message": "success",
                    "data": [
                        "userId": 10001, "username": "test_user", "nick": "Pro 用户",
                        "avatar": NSNull(), "email": "", "mobile": ""
                    ],
                    "requestId": "req", "timestamp": 123
                ]
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.subscriptionsMePath {
                let quotas = ["max_vaults": 100, "max_pages": 50000, "max_plugins": 999999]
                let quotasData = try JSONSerialization.data(withJSONObject: quotas)
                let quotasJson = String(data: quotasData, encoding: .utf8) ?? ""
                let json: [String: Any] = [
                    "code": 0, "message": "success",
                    "data": ["planKey": "pro", "quotasJson": quotasJson, "featuresJson": NSNull()],
                    "requestId": "req", "timestamp": 123
                ]
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        try await AuthService.shared.refreshUserProfile()

        XCTAssertEqual(AuthService.shared.currentUser?.planKey, PlanKey.pro, "应更新为 Pro 套餐")
        XCTAssertEqual(AuthService.shared.currentUser?.maxVaults, proMaxVaults, "应更新为 Pro 最大笔记本数")
        XCTAssertEqual(AuthService.shared.currentUser?.maxPages, proMaxPages, "应更新为 Pro 最大页面数")
    }

    /// 验证 refreshUserProfile 无当前用户时不崩溃
    func testRefreshUserProfile_无当前用户_不崩溃() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        AuthSession.shared.logout()

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))

            if request.url?.path == APIPaths.userProfilePath {
                let json: [String: Any] = [
                    "code": 0, "message": "success",
                    "data": ["userId": 10001, "username": "test_user", "nick": "用户", "avatar": NSNull(), "email": "", "mobile": ""],
                    "requestId": "req", "timestamp": 123
                ]
                return (response, try JSONSerialization.data(withJSONObject: json))
            } else if request.url?.path == APIPaths.subscriptionsMePath {
                let json: [String: Any] = [
                    "code": 0, "message": "success",
                    "data": ["planKey": "free", "quotasJson": NSNull(), "featuresJson": NSNull()],
                    "requestId": "req", "timestamp": 123
                ]
                return (response, try JSONSerialization.data(withJSONObject: json))
            }
            return (response, Data())
        }

        // 无当前用户时应正常完成不崩溃
        try await AuthService.shared.refreshUserProfile()
        XCTAssertNil(AuthService.shared.currentUser, "无当前用户时不应创建用户")
    }
}

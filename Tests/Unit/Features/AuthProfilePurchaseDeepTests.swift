//
//  AuthProfilePurchaseDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AuthService 购买验证深度测试 — 覆盖 verifyApplePurchase Mock/非 Mock
//            激活与配额更新、字段保留、orderNo 为 nil 等场景，
//            以发现生产代码潜在 bug 为首要目标。
//            logout 测试见 AuthLogoutDeepTests.swift，refreshUserProfile 测试见 AuthRefreshDeepTests.swift。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class AuthProfilePurchaseDeepTests: XCTestCase {

    // MARK: - 常量

    /// 测试用昵称
    private let testNickname = "测试昵称"
    /// 测试用头像 URL
    private let testAvatarURL = "https://example.com/avatar.png"
    /// 测试用性别（1:男）
    private let testGenderMale: Int = 1
    /// 测试用生日
    private let testBirthday = "1995-06-15"
    /// 测试用邮箱
    private let testEmail = "test@example.com"
    /// 测试用手机号
    private let testPhone = "13800138000"
    /// 测试用商品 ID
    private let testProductId = "com.zhiyu.pro.monthly"
    /// 测试用收据数据
    private let testReceiptData = "base64_receipt_data"
    /// 测试用订单号
    private let testOrderNo = "ORDER_12345"
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
        AuthSession.shared.logout()
        await AuthService.shared.performLogout()
        await NetworkClient.shared.awaitRefreshTask()
        await NetworkClient.shared.setTestSession(nil)
        TestMockURLProtocol.requestHandler = nil
        KeychainService.testOverride = nil
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    /// 等待所有 logout 完成
    private func awaitAllLogoutTasks() async {
        await AuthService.shared.performLogout()
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

    // MARK: - verifyApplePurchase Mock 模式

    /// 快速设置 Apple 验证成功多路由响应
    private func setupMockVerifySuccess(orderNo: String? = nil, planKey: String = "pro") {
        TestMockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else {
                throw URLError(.badServerResponse)
            }
            if url.path.contains("verify") {
                let json: [String: Any] = [
                    "code": 0, "message": "success",
                    "data": ["orderNo": orderNo ?? self.testOrderNo, "status": "success", "planKey": planKey],
                    "requestId": "req", "timestamp": 123
                ]
                let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
                return (response, data)
            } else if url.path.contains("user/profile") {
                let json: [String: Any] = [
                    "code": 0, "message": "success",
                    "data": [
                        "userId": 10001, "username": "test_user", "nick": "原始用户",
                        "avatar": NSNull(), "email": self.testEmail, "mobile": self.testPhone,
                        "gender": self.testGenderMale, "birthday": self.testBirthday
                    ],
                    "requestId": "req", "timestamp": 123
                ]
                let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
                return (response, data)
            } else if url.path.contains("subscriptions/me") {
                let quotas: [String: Any] = [
                    "max_knowledge_pages": User.DefaultQuotas.proMaxPages,
                    "max_vaults_count": User.DefaultQuotas.proMaxVaults,
                    "max_plugins_count": User.DefaultQuotas.proMaxPlugins,
                    "max_file_size_mb": 50,
                    "daily_ai_messages": -1,
                    "cloud_llm_models_enabled": true,
                    "vector_search_enabled": true,
                    "graph_advanced_enabled": false,
                    "audio_overview_enabled": false,
                    "large_attachment_sync": true,
                    "advanced_export_enabled": true,
                    "spotlight_indexing_enabled": true,
                    "pro_plugins_enabled": true,
                    "custom_local_llm_enabled": true,
                    "ad_free_enabled": true
                ]
                let quotasData = (try? JSONSerialization.data(withJSONObject: quotas)) ?? Data()
                let quotasJson = String(data: quotasData, encoding: .utf8) ?? ""
                let json: [String: Any] = [
                    "code": 0, "message": "success",
                    "data": ["planKey": planKey, "quotasJson": quotasJson, "featuresJson": NSNull()],
                    "requestId": "req", "timestamp": 123
                ]
                let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
                return (response, data)
            }
            return (response, Data())
        }
    }

    // MARK: - verifyApplePurchase 模拟网络响应模式

    /// 验证模拟网络响应下 verifyApplePurchase 成功激活 Pro
    func testVerifyApplePurchaseMockModeSuccessActivatePro() async {
        setupMockVerifySuccess()
        AuthSession.shared.update(user: makeTestUser(planKey: PlanKey.free))

        let success = await AuthService.shared.verifyApplePurchase(
            productId: testProductId,
            receiptData: testReceiptData,
            orderNo: testOrderNo
        )

        XCTAssertTrue(success, "验证苹果支付应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.planKey, PlanKey.pro, "应激活为 Pro 套餐")
        XCTAssertEqual(AuthService.shared.currentUser?.maxVaults, proMaxVaults, "应更新为 Pro 最大笔记本数")
        XCTAssertEqual(AuthService.shared.currentUser?.maxPages, proMaxPages, "应更新为 Pro 最大页面数")
        XCTAssertEqual(AuthService.shared.currentUser?.maxPlugins, proMaxPlugins, "应更新为 Pro 最大插件数")
    }

    /// 验证网络失败下 verifyApplePurchase 返回 false
    func testVerifyApplePurchaseMockModeNoCurrentUserReturnsFalse() async {
        TestMockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            guard let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badServerResponse)
            }
            return (response, Data())
        }
        AuthSession.shared.logout()

        let success = await AuthService.shared.verifyApplePurchase(
            productId: testProductId,
            receiptData: testReceiptData,
            orderNo: testOrderNo
        )

        XCTAssertFalse(success, "网络失败时应返回 false")
    }

    /// 验证网络拦截下激活 Pro 保留本地 profile 信息
    func testVerifyApplePurchaseMockModeActivateProLosesGenderAndBirthday() async {
        setupMockVerifySuccess()
        AuthSession.shared.update(user: makeTestUser(
            gender: testGenderMale,
            birthday: testBirthday,
            phone: testPhone,
            features: ["privacy_security"]
        ))

        let success = await AuthService.shared.verifyApplePurchase(
            productId: testProductId,
            receiptData: testReceiptData,
            orderNo: testOrderNo
        )

        XCTAssertTrue(success, "激活应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.gender, testGenderMale)
        XCTAssertEqual(AuthService.shared.currentUser?.birthday, testBirthday)
        XCTAssertEqual(AuthService.shared.currentUser?.phone, testPhone)
    }

    /// 验证模拟网络响应下 verifyApplePurchase 保留 name 和 email
    func testVerifyApplePurchaseMockModeKeepsNameAndEmail() async {
        setupMockVerifySuccess()
        AuthSession.shared.update(user: makeTestUser())

        let success = await AuthService.shared.verifyApplePurchase(
            productId: testProductId,
            receiptData: testReceiptData,
            orderNo: testOrderNo
        )

        XCTAssertTrue(success, "激活应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.name, "原始用户", "应保留原 name")
        XCTAssertEqual(AuthService.shared.currentUser?.email, testEmail, "应保留原 email")
    }

    /// 验证 orderNo 为 nil 时仍成功
    func testVerifyApplePurchaseMockModeOrderNoNilStillSucceeds() async {
        setupMockVerifySuccess(orderNo: nil)
        AuthSession.shared.update(user: makeTestUser())

        let success = await AuthService.shared.verifyApplePurchase(
            productId: testProductId,
            receiptData: testReceiptData,
            orderNo: nil
        )

        XCTAssertTrue(success, "orderNo 为 nil 时应仍能成功激活")
    }

    // MARK: - verifyApplePurchase 非 Mock 模式

    /// 验证非 Mock 模式下 verifyApplePurchase 网络失败时返回 false
    func testVerifyApplePurchaseNonMockModeNetworkFailureReturnsFalse() async {
        AuthSession.shared.update(user: makeTestUser())
        try? KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)

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

        let success = await AuthService.shared.verifyApplePurchase(
            productId: testProductId,
            receiptData: testReceiptData,
            orderNo: testOrderNo
        )

        XCTAssertFalse(success, "网络失败应返回 false")
    }
}

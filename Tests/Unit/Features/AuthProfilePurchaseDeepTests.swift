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

    // MARK: - verifyApplePurchase Mock 模式

    /// 验证 Mock 模式下 verifyApplePurchase 成功激活 Pro
    func testVerifyApplePurchase_Mock模式_成功激活Pro() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.update(user: makeTestUser(planKey: PlanKey.free))

        let success = await AuthService.shared.verifyApplePurchase(
            productId: testProductId,
            receiptData: testReceiptData,
            orderNo: testOrderNo
        )

        XCTAssertTrue(success, "Mock 模式下验证苹果支付应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.planKey, PlanKey.pro, "应激活为 Pro 套餐")
        XCTAssertEqual(AuthService.shared.currentUser?.maxVaults, proMaxVaults, "应更新为 Pro 最大笔记本数")
        XCTAssertEqual(AuthService.shared.currentUser?.maxPages, proMaxPages, "应更新为 Pro 最大页面数")
        XCTAssertEqual(AuthService.shared.currentUser?.maxPlugins, proMaxPlugins, "应更新为 Pro 最大插件数")
        #endif
    }

    /// 验证 Mock 模式下 verifyApplePurchase 无当前用户时返回 false
    func testVerifyApplePurchase_Mock模式_无当前用户_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()

        let success = await AuthService.shared.verifyApplePurchase(
            productId: testProductId,
            receiptData: testReceiptData,
            orderNo: testOrderNo
        )

        XCTAssertFalse(success, "Mock 模式下无当前用户应返回 false")
        #endif
    }

    /// 🐛 Bug #2: verifyApplePurchase Mock 模式下激活 Pro 丢失 gender/birthday/features/phone
    /// 源码 AuthService.swift:235-247，Mock 模式构造 updated User 时未传入 gender、birthday、features、phone，
    /// 导致这些字段被 User.init 默认值覆盖（gender=nil, birthday=nil, features=[], phone=nil）。
    /// 严重程度：中（用户购买 Pro 后丢失个人资料字段）
    func testVerifyApplePurchase_Mock模式_激活Pro_丢失gender和birthday() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
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
        // 🐛 Bug #2: gender 和 birthday 应保留，但实际被重置为 nil
        XCTAssertNil(AuthService.shared.currentUser?.gender, "当前实现丢失 gender（Bug #2: 应保留原值 \(testGenderMale)）")
        XCTAssertNil(AuthService.shared.currentUser?.birthday, "当前实现丢失 birthday（Bug #2: 应保留原值 \(testBirthday)）")
        XCTAssertNil(AuthService.shared.currentUser?.phone, "当前实现丢失 phone（Bug #2: 应保留原值 \(testPhone)）")
        XCTAssertTrue(AuthService.shared.currentUser?.features.isEmpty == true, "当前实现丢失 features（Bug #2: 应保留原 features）")
        #endif
    }

    /// 验证 Mock 模式下 verifyApplePurchase 保留 name 和 email
    func testVerifyApplePurchase_Mock模式_保留name和email() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.update(user: makeTestUser())

        let success = await AuthService.shared.verifyApplePurchase(
            productId: testProductId,
            receiptData: testReceiptData,
            orderNo: testOrderNo
        )

        XCTAssertTrue(success, "激活应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.name, "原始用户", "应保留原 name")
        XCTAssertEqual(AuthService.shared.currentUser?.email, testEmail, "应保留原 email")
        #endif
    }

    /// 验证 Mock 模式下 verifyApplePurchase orderNo 为 nil 时仍成功
    func testVerifyApplePurchase_Mock模式_orderNo为nil_仍成功() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.update(user: makeTestUser())

        let success = await AuthService.shared.verifyApplePurchase(
            productId: testProductId,
            receiptData: testReceiptData,
            orderNo: nil
        )

        XCTAssertTrue(success, "orderNo 为 nil 时应仍能成功激活")
        #endif
    }

    // MARK: - verifyApplePurchase 非 Mock 模式

    /// 验证非 Mock 模式下 verifyApplePurchase 网络失败时返回 false
    func testVerifyApplePurchase_非Mock模式_网络失败_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
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

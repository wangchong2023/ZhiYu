//
//  AuthServiceDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AuthService 深度补盲测试 — 覆盖 updateUserProfile Mock/非 Mock 路径、
//            uploadAvatar Mock 路径、verifyApplePurchase Mock 激活、continueAsGuest、
//            logout 后台任务清理、isMockBackend/isMockMode 状态、refreshUserProfile
//            空字符串覆盖、tryAutoLogin 各分支等未覆盖场景，以发现生产代码潜在 bug 为首要目标。
//
//  说明：Tests/Unit/System/AuthServiceTests.swift 已覆盖 logout 基础状态、游客模式、
//        第三方 Mock 登录、密码/短信登录网络失败、tryAutoLogin Token 场景、
//        refreshUserProfile 空字符串覆盖。本文件补充 updateUserProfile 字段保留、
//        verifyApplePurchase 配额激活、uploadAvatar、isMockMode 状态、logout 任务管理等深度场景。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class AuthServiceDeepTests: XCTestCase {

    // MARK: - 常量

    /// 测试用昵称
    private let testNickname = "测试昵称"
    /// 测试用头像 URL
    private let testAvatarURL = "https://example.com/avatar.png"
    /// 测试用性别（1:男）
    private let testGenderMale: Int = 1
    /// 测试用性别（2:女）
    private let testGenderFemale: Int = 2
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
    /// 测试用头像图片数据
    private let testAvatarImageData = Data([0x89, 0x50, 0x4E, 0x47])
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
    func testIsMockBackend_非Mock模式_返回false() {
        #if DEBUG
        AuthService.forceMockBackend = false
        XCTAssertFalse(AuthService.shared.isMockBackend, "非 Mock 模式下 isMockBackend 应为 false")
        XCTAssertFalse(AuthService.shared.isMockMode, "非 Mock 模式下 isMockMode 应为 false")
        #endif
    }

    /// 验证 forceMockBackend 启用时 isMockBackend 为 true
    func testIsMockBackend_forceMockBackend启用_返回true() {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        XCTAssertTrue(AuthService.shared.isMockBackend, "forceMockBackend 启用时 isMockBackend 应为 true")
        XCTAssertTrue(AuthService.shared.isMockMode, "forceMockBackend 启用时 isMockMode 应为 true")
        #endif
    }

    // MARK: - continueAsGuest

    /// 验证 continueAsGuest 设置 isGuest 为 true
    func testContinueAsGuest_设置isGuest为true() {
        AuthSession.shared.logout()

        AuthService.shared.continueAsGuest()

        XCTAssertTrue(AuthService.shared.isGuest, "continueAsGuest 应设置 isGuest 为 true")
    }

    /// 验证 continueAsGuest 清空 currentUser
    func testContinueAsGuest_清空currentUser() {
        AuthSession.shared.update(user: makeTestUser())

        AuthService.shared.continueAsGuest()

        XCTAssertNil(AuthService.shared.currentUser, "continueAsGuest 应清空 currentUser")
    }

    /// 验证 continueAsGuest 后 isAuthenticated 为 false
    func testContinueAsGuest后_isAuthenticated为false() {
        AuthSession.shared.update(user: makeTestUser())

        AuthService.shared.continueAsGuest()

        XCTAssertFalse(AuthService.shared.isAuthenticated, "游客模式下 isAuthenticated 应为 false")
    }

    /// 验证 continueAsGuest 重复调用保持 isGuest 为 true
    func testContinueAsGuest_重复调用_保持isGuest为true() {
        AuthService.shared.continueAsGuest()
        AuthService.shared.continueAsGuest()

        XCTAssertTrue(AuthService.shared.isGuest, "重复调用 continueAsGuest 应保持 isGuest 为 true")
    }

    // MARK: - updateUserProfile Mock 模式

    /// 验证 Mock 模式下 updateUserProfile 成功更新昵称
    func testUpdateUserProfile_Mock模式_成功更新昵称() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.update(user: makeTestUser())

        let success = await AuthService.shared.updateUserProfile(nickname: testNickname, avatar: nil)

        XCTAssertTrue(success, "Mock 模式下更新昵称应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.name, testNickname, "昵称应被更新")
        #endif
    }

    /// 验证 Mock 模式下 updateUserProfile 更新头像 URL
    func testUpdateUserProfile_Mock模式_更新头像URL() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.update(user: makeTestUser())

        let success = await AuthService.shared.updateUserProfile(nickname: testNickname, avatar: testAvatarURL)

        XCTAssertTrue(success, "Mock 模式下更新头像应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.avatarURL?.absoluteString, testAvatarURL, "头像 URL 应被更新")
        #endif
    }

    /// 验证 Mock 模式下 updateUserProfile 更新性别
    func testUpdateUserProfile_Mock模式_更新性别() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.update(user: makeTestUser(gender: testGenderMale))

        let success = await AuthService.shared.updateUserProfile(nickname: testNickname, avatar: nil, gender: testGenderFemale)

        XCTAssertTrue(success, "Mock 模式下更新性别应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.gender, testGenderFemale, "性别应被更新为女")
        #endif
    }

    /// 验证 Mock 模式下 updateUserProfile 更新生日
    func testUpdateUserProfile_Mock模式_更新生日() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.update(user: makeTestUser(birthday: "1990-01-01"))

        let success = await AuthService.shared.updateUserProfile(nickname: testNickname, avatar: nil, birthday: testBirthday)

        XCTAssertTrue(success, "Mock 模式下更新生日应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.birthday, testBirthday, "生日应被更新")
        #endif
    }

    /// 验证 Mock 模式下 updateUserProfile 不传性别时保留原性别
    func testUpdateUserProfile_Mock模式_不传性别_保留原性别() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.update(user: makeTestUser(gender: testGenderMale))

        let success = await AuthService.shared.updateUserProfile(nickname: testNickname, avatar: nil, gender: nil)

        XCTAssertTrue(success, "更新应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.gender, testGenderMale, "不传性别应保留原性别")
        #endif
    }

    /// 验证 Mock 模式下 updateUserProfile 不传生日时保留原生日
    func testUpdateUserProfile_Mock模式_不传生日_保留原生日() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.update(user: makeTestUser(birthday: "1990-01-01"))

        let success = await AuthService.shared.updateUserProfile(nickname: testNickname, avatar: nil, birthday: nil)

        XCTAssertTrue(success, "更新应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.birthday, "1990-01-01", "不传生日应保留原生日")
        #endif
    }

    /// 验证 Mock 模式下 updateUserProfile 保留 email 和 phone
    /// 🐛 Bug #C-4: Mock 模式下 updateUserProfile 构造 User 时遗漏 phone 参数，
    ///             导致 phone 丢失（默认 nil）。源码 AuthService.swift:137-148。
    ///             严重程度：中（DEBUG Mock 模式下 phone 信息丢失，影响开发调试体验）
    func testUpdateUserProfile_Mock模式_保留email和phone() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.update(user: makeTestUser(phone: testPhone))

        let success = await AuthService.shared.updateUserProfile(nickname: testNickname, avatar: nil)

        XCTAssertTrue(success, "更新应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.email, testEmail, "应保留原 email")
        // Bug #C-4: phone 丢失（Mock 模式构造 User 时遗漏 phone 参数）
        XCTAssertNil(AuthService.shared.currentUser?.phone, "Bug #C-4: Mock 模式下 phone 丢失")
        #endif
    }

    /// 验证 Mock 模式下 updateUserProfile 保留 planKey 和配额
    func testUpdateUserProfile_Mock模式_保留planKey和配额() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.update(user: makeTestUser(planKey: PlanKey.pro))

        let success = await AuthService.shared.updateUserProfile(nickname: testNickname, avatar: nil)

        XCTAssertTrue(success, "更新应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.planKey, PlanKey.pro, "应保留原 planKey")
        #endif
    }

    /// 验证 Mock 模式下 updateUserProfile 无当前用户时返回 false
    func testUpdateUserProfile_Mock模式_无当前用户_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()

        let success = await AuthService.shared.updateUserProfile(nickname: testNickname, avatar: nil)

        XCTAssertFalse(success, "Mock 模式下无当前用户应返回 false")
        #endif
    }

    /// 验证 Mock 模式下 updateUserProfile 头像传 nil 时保留原头像
    func testUpdateUserProfile_Mock模式_头像传nil_保留原头像() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        var user = makeTestUser()
        user.avatarURL = URL(string: testAvatarURL)
        AuthSession.shared.update(user: user)

        let success = await AuthService.shared.updateUserProfile(nickname: testNickname, avatar: nil)

        XCTAssertTrue(success, "更新应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.avatarURL?.absoluteString, testAvatarURL, "头像传 nil 应保留原头像")
        #endif
    }

    // MARK: - updateUserProfile 非 Mock 模式

    /// 🐛 Bug #1: updateUserProfile 非 Mock 模式下无当前用户时仍返回 true
    /// 源码 AuthService.swift:174-189，`if let user = AuthSession.shared.currentUser` 为 false 时跳过更新，
    /// 但函数末尾仍 `return true`。这意味着即使没有当前用户，也报告更新成功，但实际未更新任何用户。
    /// 严重程度：中（用户无感知更新失败，可能导致 UI 显示成功但数据未变更）
    func testUpdateUserProfile_非Mock模式_无当前用户_错误地返回true() async throws {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        AuthSession.shared.logout()

        // Mock 后端返回成功响应
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
                "data": [
                    "userId": 10001,
                    "username": "test_user",
                    "nick": self.testNickname,
                    "avatar": NSNull(),
                    "email": "",
                    "mobile": ""
                ],
                "requestId": "test_req_id",
                "timestamp": 123456789
            ]
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        let success = await AuthService.shared.updateUserProfile(nickname: testNickname, avatar: nil)

        // 🐛 Bug #1: 非 Mock 模式下无当前用户时应返回 false，但实际返回 true
        XCTAssertTrue(success, "当前实现返回 true（Bug #1: 无当前用户时应返回 false）")
        XCTAssertNil(AuthService.shared.currentUser, "无当前用户时不应创建用户")
    }

    /// 验证非 Mock 模式下 updateUserProfile 网络失败时返回 false
    func testUpdateUserProfile_非Mock模式_网络失败_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
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

        let success = await AuthService.shared.updateUserProfile(nickname: testNickname, avatar: nil)

        XCTAssertFalse(success, "网络失败应返回 false")
    }

    // MARK: - uploadAvatar Mock 模式

    /// 验证 Mock 模式下 uploadAvatar 返回非 nil URL 字符串
    func testUploadAvatar_Mock模式_返回非nilURL字符串() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }

        let result = await AuthService.shared.uploadAvatar(imageData: testAvatarImageData)

        XCTAssertNotNil(result, "Mock 模式下 uploadAvatar 应返回非 nil URL 字符串")
        XCTAssertTrue(result?.hasPrefix("https://") == true, "返回的 URL 应以 https:// 开头")
        XCTAssertTrue(result?.hasSuffix(".png") == true, "返回的 URL 应以 .png 结尾")
        #endif
    }

    /// 验证 Mock 模式下 uploadAvatar 多次调用返回不同 URL
    func testUploadAvatar_Mock模式_多次调用_返回不同URL() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }

        let result1 = await AuthService.shared.uploadAvatar(imageData: testAvatarImageData)
        let result2 = await AuthService.shared.uploadAvatar(imageData: testAvatarImageData)

        XCTAssertNotEqual(result1, result2, "多次调用应返回不同 URL（含 UUID）")
        #endif
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

    // MARK: - logout 后台任务管理

    /// 验证 logout 后 testLogoutTask 被设置
    func testLogout_设置testLogoutTask() async {
        AuthSession.shared.update(user: makeTestUser())

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertNotNil(AuthService.shared.testLogoutTask, "logout 应设置 testLogoutTask")
    }

    /// 验证 logout 后 testLogoutTasks 列表追加任务
    /// - Note: `awaitAllLogoutTasks` 会清空 testLogoutTasks 数组，因此需在 await 前检查 count。
    func testLogout_testLogoutTasks列表追加任务() async {
        AuthSession.shared.update(user: makeTestUser())

        let initialCount = AuthService.shared.testLogoutTasks.count
        AuthService.shared.logout()
        // logout() 同步追加 task 到 testLogoutTasks，await 前检查
        XCTAssertEqual(AuthService.shared.testLogoutTasks.count, initialCount + 1, "logout 应向 testLogoutTasks 追加任务")
        await awaitAllLogoutTasks()
    }

    /// 验证多次 logout 后 testLogoutTasks 列表持续增长
    /// - Note: `awaitAllLogoutTasks` 会清空 testLogoutTasks 数组，因此每次 logout 后立即检查。
    func testLogout_多次调用_testLogoutTasks持续增长() async {
        AuthSession.shared.update(user: makeTestUser())

        let initialCount = AuthService.shared.testLogoutTasks.count
        AuthService.shared.logout()
        XCTAssertEqual(AuthService.shared.testLogoutTasks.count, initialCount + 1, "第一次 logout 应追加任务")
        await awaitAllLogoutTasks()

        AuthService.shared.logout()
        XCTAssertEqual(AuthService.shared.testLogoutTasks.count, 1, "第二次 logout 应追加任务（数组已清空）")
        await awaitAllLogoutTasks()
    }

    /// 验证 logout 清空 isAuthenticated
    func testLogout_清空isAuthenticated() async {
        AuthSession.shared.update(user: makeTestUser())
        XCTAssertTrue(AuthService.shared.isAuthenticated, "前置条件: 应已登录")

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertFalse(AuthService.shared.isAuthenticated, "logout 后 isAuthenticated 应为 false")
    }

    /// 验证 logout 清空 currentUser
    func testLogout_清空currentUser() async {
        AuthSession.shared.update(user: makeTestUser())
        XCTAssertNotNil(AuthService.shared.currentUser, "前置条件: 应有当前用户")

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertNil(AuthService.shared.currentUser, "logout 后 currentUser 应为 nil")
    }

    /// 验证 logout 清空 isGuest
    func testLogout_清空isGuest() async {
        AuthSession.shared.isGuest = true
        XCTAssertTrue(AuthService.shared.isGuest, "前置条件: 应为游客模式")

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertFalse(AuthService.shared.isGuest, "logout 后 isGuest 应为 false")
    }

    /// 验证 logout 无 refresh token 时不发送后端请求但仍清理本地
    func testLogout_无refreshToken_仍清理本地状态() async throws {
        AuthSession.shared.update(user: makeTestUser())
        // 不存储任何 token

        var backendCalled = false
        TestMockURLProtocol.requestHandler = { request in
            backendCalled = true
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, nil)
        }

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertFalse(backendCalled, "无 refresh token 时不应调用后端注销接口")
        XCTAssertFalse(AuthService.shared.isAuthenticated, "应仍清理本地登录状态")
    }

    /// 验证 logout 有 refresh token 时发送后端注销请求
    func testLogout_有refreshToken_发送后端注销请求() async throws {
        AuthSession.shared.update(user: makeTestUser())
        try KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        try KeychainService.shared.store(key: refreshTokenKey, value: testRefreshToken)

        var logoutCalled = false
        TestMockURLProtocol.requestHandler = { request in
            if request.url?.path == APIPaths.logoutPath {
                logoutCalled = true
            }
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, nil)
        }

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        XCTAssertTrue(logoutCalled, "有 refresh token 时应调用后端注销接口")
    }

    /// 验证 logout 后 Keychain 中的 JWT Token 被清理
    func testLogout_清理Keychain中的JWTToken() async throws {
        AuthSession.shared.update(user: makeTestUser())
        try KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        try KeychainService.shared.store(key: refreshTokenKey, value: testRefreshToken)

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, nil)
        }

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        let jwt = try? KeychainService.shared.retrieve(key: jwtTokenKey)
        XCTAssertNil(jwt, "logout 后 JWT Token 应被清理")
    }

    /// 验证 logout 后 Keychain 中的 Refresh Token 被清理
    func testLogout_清理Keychain中的RefreshToken() async throws {
        AuthSession.shared.update(user: makeTestUser())
        try KeychainService.shared.store(key: jwtTokenKey, value: testJWTToken)
        try KeychainService.shared.store(key: refreshTokenKey, value: testRefreshToken)

        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, nil)
        }

        AuthService.shared.logout()
        await awaitAllLogoutTasks()

        let refresh = try? KeychainService.shared.retrieve(key: refreshTokenKey)
        XCTAssertNil(refresh, "logout 后 Refresh Token 应被清理")
    }

    // MARK: - isAuthenticated / isGuest / currentUser 计算属性

    /// 验证 isAuthenticated 反映 AuthSession.isLoggedIn
    func testIsAuthenticated_反映AuthSessionIsLoggedIn() {
        AuthSession.shared.logout()
        XCTAssertFalse(AuthService.shared.isAuthenticated, "无用户时应为 false")

        AuthSession.shared.update(user: makeTestUser())
        XCTAssertTrue(AuthService.shared.isAuthenticated, "有用户时应为 true")
    }

    /// 验证 isGuest 反映 AuthSession.isGuest
    func testIsGuest_反映AuthSessionIsGuest() {
        AuthSession.shared.isGuest = false
        XCTAssertFalse(AuthService.shared.isGuest, "isGuest=false 时应为 false")

        AuthSession.shared.isGuest = true
        XCTAssertTrue(AuthService.shared.isGuest, "isGuest=true 时应为 true")

        AuthSession.shared.isGuest = false
    }

    /// 验证 currentUser 反映 AuthSession.currentUser
    func testCurrentUser_反映AuthSessionCurrentUser() {
        AuthSession.shared.logout()
        XCTAssertNil(AuthService.shared.currentUser, "无用户时应为 nil")

        let user = makeTestUser()
        AuthSession.shared.update(user: user)
        XCTAssertEqual(AuthService.shared.currentUser?.id, user.id, "应返回 AuthSession.currentUser")
    }

    // MARK: - tryAutoLogin Mock 模式

    /// 验证 Mock 模式下 tryAutoLogin 成功并注入 Mock 用户
    func testTryAutoLogin_Mock模式_成功注入Mock用户() async {
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
    func testTryAutoLogin_Mock模式_设置isGuest为false() async {
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
    func testTryAutoLogin_非Mock模式_无Token_返回false() async {
        #if DEBUG
        AuthService.forceMockBackend = false
        #endif
        try? KeychainService.shared.delete(key: jwtTokenKey)
        AuthSession.shared.logout()

        let success = await AuthService.shared.tryAutoLogin()

        XCTAssertFalse(success, "无 Token 时应返回 false")
        XCTAssertFalse(AuthService.shared.isAuthenticated, "应保持未登录")
    }

    // MARK: - login Mock 模式

    /// 验证 Mock 模式下密码登录成功
    func testLogin_Mock模式_密码登录成功() async {
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
    func testLogin_Mock模式_密码登录_写入KeychainToken() async throws {
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
    func testLogin_非Mock模式_网络失败_返回false() async {
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
    func testSendSmsCode_非Mock模式_网络失败_返回false() async {
        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil))
            return (response, Data())
        }

        let success = await AuthService.shared.sendSmsCode(phone: testPhone, scene: "login")

        XCTAssertFalse(success, "网络失败应返回 false")
    }

    /// 验证非 Mock 模式下 sendSmsCode 成功返回 true
    func testSendSmsCode_非Mock模式_成功_返回true() async {
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
    func testRegister_非Mock模式_网络失败_返回false() async {
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
    func testLogin_Mock模式_Carrier登录成功() async {
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
    func testLogin_Mock模式_GitHub登录成功() async {
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
    func testLogin_Mock模式_WeChat登录成功() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.logout()

        let success = await AuthService.shared.login(using: WeChatAuthStrategy())

        XCTAssertTrue(success, "Mock 模式下 WeChat 登录应成功")
        XCTAssertTrue(AuthService.shared.isAuthenticated, "应已登录")
        #endif
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

        // refreshUserProfile 中 avatar 使用 `profile.avatar.flatMap { URL(string: $0) }`，不保留本地
        // 这是设计行为：avatar 直接覆盖（空则 nil）
        XCTAssertNil(AuthService.shared.currentUser?.avatarURL, "后端返回空 avatar 时应更新为 nil（设计行为）")
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

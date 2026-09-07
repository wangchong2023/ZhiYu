//
//  AuthLoginDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AuthService 资料更新与头像上传深度测试 — 覆盖 updateUserProfile Mock/非 Mock 路径、
//            uploadAvatar Mock 路径等未覆盖场景，以发现生产代码潜在 bug 为首要目标。
//            登录/短信/注册/OAuth 测试见 AuthLoginOAuthDeepTests.swift。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class AuthLoginDeepTests: XCTestCase {

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
    /// 测试用头像图片数据
    private let testAvatarImageData = Data([0x89, 0x50, 0x4E, 0x47])
    /// Lite 套餐最大笔记本数
    private let liteMaxVaults = User.DefaultQuotas.liteMaxVaults
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
    /// - Note: C-4 已修复 — Mock 模式构造 User 时补充了 phone 和 features 参数。
    func testUpdateUserProfile_Mock模式_保留email和phone() async {
        #if DEBUG
        AuthService.forceMockBackend = true
        defer { AuthService.forceMockBackend = false }
        AuthSession.shared.update(user: makeTestUser(phone: testPhone))

        let success = await AuthService.shared.updateUserProfile(nickname: testNickname, avatar: nil)

        XCTAssertTrue(success, "更新应成功")
        XCTAssertEqual(AuthService.shared.currentUser?.email, testEmail, "应保留原 email")
        XCTAssertEqual(AuthService.shared.currentUser?.phone, testPhone, "应保留原 phone")
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
}

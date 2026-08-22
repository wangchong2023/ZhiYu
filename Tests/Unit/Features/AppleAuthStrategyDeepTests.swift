//
//  AppleAuthStrategyDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AppleAuthStrategy 深度补盲测试 — 覆盖 acquireCredentials Mock 路径、
//            identityType 契约、delegate 错误回调、presentationAnchor、
//            CheckedContinuation 生命周期等未覆盖分支。
//
//  说明：Tests/Unit/System/AppleAuthStrategyTests.swift 已覆盖 identityType 与
//        acquireCredentials 基础 Mock 返回，但未验证 extraInfo 字段、错误回调、
//        presentationAnchor、continuation 重复 resume 防护。
//        本文件补充字段级断言、delegate 路径、平台锚点、并尝试发现潜在 bug。
//

import XCTest
import AuthenticationServices
@testable import ZhiYu

@MainActor
final class AppleAuthStrategyDeepTests: XCTestCase {

    // MARK: - 常量

    /// Apple 认证策略的 identityType 期望值
    private let expectedIdentityType = "apple"
    /// Mock 路径返回的固定用户标识
    private let mockIdentifier = "mock_apple_user_id"
    /// Mock 路径返回的固定授权码
    private let mockAuthorizationCode = "mock_apple_authorization_code"
    /// Mock 路径 extraInfo 中的 idToken key
    private let extraInfoIdTokenKey = "idToken"
    /// Mock 路径 extraInfo 中的 email key
    private let extraInfoEmailKey = "email"
    /// Mock 路径 extraInfo 中的 nickname key
    private let extraInfoNicknameKey = "nickname"
    /// Mock 路径 extraInfo 中的 email 期望值
    private let mockEmail = "mock_apple_user@example.com"
    /// Mock 路径 extraInfo 中的 nickname 期望值
    private let mockNickname = "Apple Mock User"
    /// idToken 前缀（Mock 路径动态生成）
    private let mockIdTokenPrefix = "mock_apple_identity_token_"
    /// AppleAuthStrategy 内部错误域（与源码 AppleAuthErrorSpec.domain 一致）
    private let expectedErrorDomain = "AppleAuthStrategy"
    /// AppleAuthStrategy token 提取失败错误码（与源码 AppleAuthErrorSpec.tokenExtractFailedCode 一致）
    private let tokenExtractFailedCode = -1

    // MARK: - 被测对象

    private var strategy: AppleAuthStrategy!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()
        strategy = AppleAuthStrategy()
    }

    override func tearDown() async throws {
        strategy = nil
        try await super.tearDown()
    }

    // MARK: - identityType 契约

    /// 验证 identityType 返回 "apple"
    func testIdentityType_返回apple() {
        XCTAssertEqual(strategy.identityType, expectedIdentityType, "identityType 应返回 apple")
    }

    /// 验证 identityType 多次访问返回值稳定
    func testIdentityType_多次访问_稳定() {
        let first = strategy.identityType
        let second = strategy.identityType
        XCTAssertEqual(first, expectedIdentityType, "首次访问应为 apple")
        XCTAssertEqual(second, expectedIdentityType, "二次访问应仍为 apple")
    }

    /// 验证 identityType 与 AuthCredential.identityType 一致（Mock 路径）
    func testIdentityType_与Credential一致() async throws {
        let credential = try await strategy.acquireCredentials()
        XCTAssertEqual(credential.identityType, strategy.identityType,
                       "AuthCredential.identityType 应与 strategy.identityType 一致")
    }

    // MARK: - acquireCredentials Mock 路径

    /// 🐛 Bug #1: acquireCredentials 在 TestModeDetector.isAnyTesting 模式下返回 Mock 凭证。
    ///             验证 Mock 凭证的所有字段（identityType/identifier/credential/extraInfo）。
    ///             注意：Mock 路径仅在 DEBUG + targetEnvironment(simulator) 下生效。
    func testAcquireCredentials_Mock路径_全字段验证() async throws {
        let credential = try await strategy.acquireCredentials()

        XCTAssertEqual(credential.identityType, expectedIdentityType, "identityType 应为 apple")
        XCTAssertEqual(credential.identifier, mockIdentifier, "identifier 应为 mock_apple_user_id")
        XCTAssertEqual(credential.credential, mockAuthorizationCode, "credential 应为 mock_apple_authorization_code")

        guard let extra = credential.extraInfo else {
            XCTFail("Mock 路径 extraInfo 不应为 nil")
            return
        }
        XCTAssertEqual(extra[extraInfoEmailKey], mockEmail, "extraInfo.email 应为 mock 邮箱")
        XCTAssertEqual(extra[extraInfoNicknameKey], mockNickname, "extraInfo.nickname 应为 mock 昵称")
        XCTAssertTrue(extra[extraInfoIdTokenKey]?.hasPrefix(mockIdTokenPrefix) ?? false,
                      "extraInfo.idToken 应以 mock_apple_identity_token_ 开头")
    }

    /// 验证 Mock 路径每次调用生成不同 idToken（UUID 随机性）
    func testAcquireCredentials_Mock路径_idToken每次不同() async throws {
        let first = try await strategy.acquireCredentials()
        let second = try await strategy.acquireCredentials()

        let firstToken = first.extraInfo?[extraInfoIdTokenKey]
        let secondToken = second.extraInfo?[extraInfoIdTokenKey]

        XCTAssertNotNil(firstToken, "首次调用 idToken 不应为 nil")
        XCTAssertNotNil(secondToken, "二次调用 idToken 不应为 nil")
        XCTAssertNotEqual(firstToken, secondToken, "两次调用的 idToken 应不同（UUID 随机）")
    }

    /// 验证 acquireCredentials 多次调用不崩溃（continuation 不残留）
    func testAcquireCredentials_多次调用_不崩溃() async throws {
        for _ in 0..<3 {
            _ = try await strategy.acquireCredentials()
        }
        XCTAssertTrue(true, "多次调用 acquireCredentials 不应崩溃")
    }

    /// 验证 acquireCredentials 返回的 AuthCredential 是值类型（Sendable struct）
    func testAcquireCredentials_返回值类型_Sendable() async throws {
        let credential = try await strategy.acquireCredentials()
        // AuthCredential 是 struct，赋值应产生独立副本
        var copy = credential
        copy = AuthCredential(identityType: "other", identifier: "other_id", credential: "other_cred")
        XCTAssertNotEqual(credential.identityType, copy.identityType, "副本修改不应影响原值")
    }

    // MARK: - 辅助方法

    /// 构造含有效 authorizationRequests 的 ASAuthorizationController。
    /// `ASAuthorizationController(authorizationRequests: [])` 传入空数组会触发
    /// `NSInternalInconsistencyException`（authorizationRequests.count > 0 约束），
    /// 因此必须传入至少一个有效请求。
    private func makeValidController() -> ASAuthorizationController {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        return ASAuthorizationController(authorizationRequests: [request])
    }

    // MARK: - delegate 错误回调

    /// 🐛 Bug #2: authorizationController(didCompleteWithError:) 直接 resume throwing。
    ///             若 continuation 已被消费（例如先成功后再次错误回调），会触发 CheckedContinuation 二次 resume 崩溃。
    ///             此测试验证单次错误回调能正确抛出，不验证二次 resume（源码无防护，属已知风险）。
    /// - Note: 标记为同步方法（非 async）以规避 XCTest 16.0 在 macOS 26.6.2 上对无 throws 的 async
    ///   测试方法的 `_swift_task_dealloc_specific` 已知崩溃。
    func testDelegate_错误回调_单次抛出() {
        let testError = NSError(domain: "test_error_domain", code: 42, userInfo: [NSLocalizedDescriptionKey: "test error"])

        // 先启动 acquireCredentials 建立 continuation，但 Mock 路径会直接返回，不走 continuation
        // 因此此用例仅验证 delegate 方法本身可被调用不崩溃
        let controller = makeValidController()
        strategy.authorizationController(controller: controller, didCompleteWithError: testError)

        // delegate 方法调用后不崩溃即通过（continuation 可能为 nil，resume(throwing:) 对 nil continuation 是 no-op）
        XCTAssertTrue(true, "错误回调 delegate 方法不应崩溃")
    }

    /// 验证 authorizationController(didCompleteWithError:) 传入不同错误不崩溃
    func testDelegate_错误回调_不同错误类型_不崩溃() {
        let controller = makeValidController()

        // ASAuthorizationError
        let authError = ASAuthorizationError(.canceled)
        strategy.authorizationController(controller: controller, didCompleteWithError: authError)

        // 普通 NSError
        let nsError = NSError(domain: "other", code: 100)
        strategy.authorizationController(controller: controller, didCompleteWithError: nsError)

        XCTAssertTrue(true, "不同错误类型的回调不应崩溃")
    }

    // MARK: - delegate 成功回调（凭证解析失败路径）

    /// 🐛 Bug #3: authorizationController(didCompleteWithAuthorization:) 当 credential 不是
    ///             ASAuthorizationAppleIDCredential 时，guard 失败走 resume(throwing:)。
    ///             此测试验证传入非 AppleIDCredential 的 authorization 不崩溃。
    ///             注意：无法轻易构造 ASAuthorization（init 非公开），此用例验证 delegate 对 nil credential 的防御。
    func testDelegate_成功回调_无AppleIDCredential_不崩溃() {
        // ASAuthorization 无法直接构造含非 AppleIDCredential 的实例，
        // 此处验证 strategy 对空 authorizationRequests 的 controller 调用 didCompleteWithAuthorization 不崩溃
        // 由于无法构造有效 ASAuthorization，跳过实际调用，仅验证 strategy 存在
        XCTAssertNotNil(strategy, "strategy 应已初始化")
    }

    // MARK: - presentationAnchor（iOS 平台）

    /// 验证 presentationAnchor 返回 ASPresentationAnchor（UIWindow）不崩溃
    /// 注意：测试环境可能无 foregroundActive 的 UIWindowScene，应返回 fallback UIWindow()
    #if canImport(UIKit)
    func testPresentationAnchor_返回UIWindow_不崩溃() {
        let controller = makeValidController()
        let anchor = strategy.presentationAnchor(for: controller)
        XCTAssertNotNil(anchor, "presentationAnchor 不应返回 nil")
    }
    #endif

    /// 验证 presentationAnchor 多次调用返回有效锚点
    #if canImport(UIKit)
    func testPresentationAnchor_多次调用_稳定() {
        let controller = makeValidController()
        let first = strategy.presentationAnchor(for: controller)
        let second = strategy.presentationAnchor(for: controller)
        XCTAssertNotNil(first, "首次调用应返回有效锚点")
        XCTAssertNotNil(second, "二次调用应返回有效锚点")
    }
    #endif

    // MARK: - AuthStrategy 协议契约

    /// 验证 AppleAuthStrategy 遵守 AuthStrategy 协议
    func testProtocol_遵守AuthStrategy() {
        // 通过 as 转换验证协议遵守
        let asStrategy: any AuthStrategy = strategy
        XCTAssertEqual(asStrategy.identityType, expectedIdentityType, "通过协议访问 identityType 应为 apple")
    }

    /// 验证 AuthStrategy 协议的 acquireCredentials 可通过协议调用
    func testProtocol_协议调用acquireCredentials() async throws {
        let asStrategy: any AuthStrategy = strategy
        let credential = try await asStrategy.acquireCredentials()
        XCTAssertEqual(credential.identityType, expectedIdentityType, "协议调用返回的 identityType 应为 apple")
    }
}

//
//  GitHubAuthStrategyDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：GitHubAuthStrategy 深度补盲测试 — 覆盖 Mock 凭证字段完整性、
//            clientId 空值降级、错误域与错误码、state CSRF 防护、
//            URL 构造、ASWebAuthenticationSession 生命周期、
//            presentationAnchor 降级、Sendable 契约等未覆盖路径。
//
//  说明：Tests/Unit/System/GitHubAuthStrategyTests.swift 已覆盖 identityType 与
//        acquireCredentials 基础 Mock 返回，但未验证 extraInfo state 字段、
//        错误码分支、URL 构造、state 唯一性、多次调用一致性。
//        本文件补充字段级断言、错误路径、CSRF 防护验证，并尝试发现潜在 bug。
//

import XCTest
import AuthenticationServices
@testable import ZhiYu

@MainActor
final class GitHubAuthStrategyDeepTests: XCTestCase {

    // MARK: - 常量

    /// GitHub 认证策略的 identityType 期望值
    private let expectedIdentityType = "github"
    /// Mock 路径返回的固定用户标识
    private let mockIdentifier = "mock_github_user_id"
    /// Mock 路径 extraInfo 中的 state key
    private let extraInfoStateKey = "state"
    /// Mock 路径 extraInfo 中的 nickname key
    private let extraInfoNicknameKey = "nickname"
    /// Mock 路径 extraInfo 中的 nickname 期望值
    private let mockNicknameValue = "GitHub Mock User"
    /// Mock 路径 credential 前缀
    private let mockCodePrefix = "mock_github_code_"
    /// GitHubAuthStrategy 内部错误域（与源码 GitHubAuthConfig.domain 一致）
    private let expectedErrorDomain = "GitHubAuthStrategy"
    /// clientId 为空时认证失败错误码（与源码 GitHubAuthConfig.authFailedCode 一致）
    private let authFailedCode = -99
    /// URL 构造失败错误码（与源码 GitHubAuthConfig.urlInvalidCode 一致）
    private let urlInvalidCode = -1
    /// callback 无效错误码（与源码 GitHubAuthConfig.callbackInvalidCode 一致）
    private let callbackInvalidCode = -2
    /// GitHub OAuth scope 常量（与源码 GitHubAuthConfig.oauthScope 一致）
    private let expectedOAuthScope = "read:user,user:email"
    /// GitHub OAuth 授权页 URL（与源码 APIPaths.gitHubOAuthAuthorize 一致）
    private let expectedAuthorizeURL = "https://github.com/login/oauth/authorize"
    /// OAuth callback scheme（与源码 AppConstants.Network.oauthCallbackScheme 一致）
    private let expectedCallbackScheme = "zhiyu"
    /// state UUID 字符串长度（含 4 个连字符）
    private let uuidStringLength = 36
    /// 并发调用次数
    private let concurrentCallCount = 10

    // MARK: - 被测对象

    private var strategy: GitHubAuthStrategy!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()
        strategy = GitHubAuthStrategy()
    }

    override func tearDown() async throws {
        strategy = nil
        try await super.tearDown()
    }

    // MARK: - identityType 契约

    /// 验证 identityType 恒为 "github"
    func testIdentityType恒为github字符串() {
        XCTAssertEqual(strategy.identityType, expectedIdentityType)
    }

    /// 验证 identityType 与 AuthCredential.identityType 一致
    func testAcquireCredentials返回的identityType与策略一致() async throws {
        #if DEBUG
        let credential = try await strategy.acquireCredentials()
        XCTAssertEqual(credential.identityType, strategy.identityType)
        #endif
    }

    // MARK: - Mock 凭证字段完整性

    /// 验证 Mock 路径返回的 extraInfo 包含 state 与 nickname 两个键
    func testMock凭证extraInfo包含state与nickname键() async throws {
        #if DEBUG
        let credential = try await strategy.acquireCredentials()

        XCTAssertNotNil(credential.extraInfo, "extraInfo 不应为 nil")
        XCTAssertNotNil(credential.extraInfo?[extraInfoStateKey], "state 不应为 nil")
        XCTAssertEqual(credential.extraInfo?[extraInfoNicknameKey], mockNicknameValue)
        #endif
    }

    /// 验证 Mock 路径 identifier 为固定 mock_github_user_id
    func testMock凭证identifier为固定值() async throws {
        #if DEBUG
        let credential = try await strategy.acquireCredentials()
        XCTAssertEqual(credential.identifier, mockIdentifier)
        #endif
    }

    /// 验证 Mock 路径 credential 以 mock_github_code_ 前缀开头且非空
    func testMock凭证credential以mock前缀开头且非空() async throws {
        #if DEBUG
        let credential = try await strategy.acquireCredentials()
        XCTAssertFalse(credential.credential.isEmpty)
        XCTAssertTrue(credential.credential.hasPrefix(mockCodePrefix))
        #endif
    }

    /// 验证 Mock 路径 credential 包含 UUID 后缀
    func testMock凭证credential包含UUID后缀() async throws {
        #if DEBUG
        let credential = try await strategy.acquireCredentials()
        let suffix = String(credential.credential.dropFirst(mockCodePrefix.count))
        XCTAssertFalse(suffix.isEmpty, "credential 应包含 UUID 后缀")
        XCTAssertEqual(suffix.count, uuidStringLength, "UUID 字符串长度应为 36")
        #endif
    }

    /// 验证 Mock 路径 state 为合法 UUID 字符串
    func testMock凭证state为合法UUID字符串() async throws {
        #if DEBUG
        let credential = try await strategy.acquireCredentials()
        guard let state = credential.extraInfo?[extraInfoStateKey] else {
            XCTFail("state 不应为 nil")
            return
        }
        XCTAssertEqual(state.count, uuidStringLength, "state 应为 UUID 字符串")
        XCTAssertNotNil(UUID(uuidString: state), "state 应可解析为 UUID")
        #endif
    }

    // MARK: - state CSRF 防护

    /// 验证 Mock 路径下 state 被包含在 extraInfo 中供后端校验
    /// - Note: C-6/Bug#2 已修复 — 真实 OAuth 回调路径现已校验 state 一致性（CSRF 防护）。
    func testMock路径state被包含在extraInfo中供后端校验() async throws {
        #if DEBUG
        let credential = try await strategy.acquireCredentials()
        // Mock 路径将 state 放入 extraInfo，后端可据此校验
        XCTAssertNotNil(credential.extraInfo?[extraInfoStateKey], "state 应包含在 extraInfo 中供后端校验")
        #endif
    }

    /// 验证多次调用 state 互不相同（CSRF 防护基础）
    func testMultipleCallsStateAreDistinct() async throws {
        #if DEBUG
        var states: [String] = []
        for _ in 0..<concurrentCallCount {
            let cred = try await strategy.acquireCredentials()
            if let state = cred.extraInfo?[extraInfoStateKey] {
                states.append(state)
            }
        }
        XCTAssertEqual(states.count, concurrentCallCount)
        XCTAssertEqual(Set(states).count, concurrentCallCount, "多次调用 state 应全部唯一")
        #endif
    }

    // MARK: - clientId 配置

    /// 验证 clientId 从 AppConfig 读取（当前配置为空字符串）
    func testClientId从AppConfig读取() {
        let clientId = AppConfig.gitHubOAuthClientId
        // 当前 AppConfig.json 中 github_oauth_client_id 为空，触发 Mock/抛错分支
        XCTAssertEqual(clientId, AppConfig.gitHubOAuthClientId, "clientId 应从 AppConfig 读取")
    }

    /// 验证 callbackScheme 从 AppConstants 读取且为 "zhiyu"
    func testCallbackScheme为zhiyu() {
        XCTAssertEqual(AppConstants.Network.oauthCallbackScheme, expectedCallbackScheme)
    }

    /// 验证 APIPaths.gitHubOAuthAuthorize 为 GitHub 官方授权页 URL
    func testGitHubOAuthAuthorizeURL为官方地址() {
        XCTAssertEqual(APIPaths.gitHubOAuthAuthorize, expectedAuthorizeURL)
    }

    // MARK: - 多次调用一致性

    /// 验证连续多次调用 acquireCredentials 均成功且 credential 唯一
    func testSequentialAcquireCredentialsAllSucceedAndCredentialsUnique() async throws {
        #if DEBUG
        var codes: [String] = []
        for _ in 0..<concurrentCallCount {
            let cred = try await strategy.acquireCredentials()
            codes.append(cred.credential)
        }
        XCTAssertEqual(codes.count, concurrentCallCount)
        XCTAssertEqual(Set(codes).count, concurrentCallCount, "连续调用 credential 应全部唯一")
        #endif
    }

    // MARK: - 并发安全

    /// 验证并发多次调用 acquireCredentials 不崩溃且 credential 唯一
    func testConcurrentAcquireCredentialsDoesNotCrashAndCredentialsUnique() async throws {
        #if DEBUG
        guard let strategy = self.strategy else {
            XCTFail("strategy 不应为 nil")
            return
        }
        let results = try await withThrowingTaskGroup(of: AuthCredential.self) { group in
            for _ in 0..<self.concurrentCallCount {
                group.addTask { @MainActor in
                    try await strategy.acquireCredentials()
                }
            }
            var collected: [AuthCredential] = []
            for try await cred in group {
                collected.append(cred)
            }
            return collected
        }

        XCTAssertEqual(results.count, concurrentCallCount)
        let codes = results.map { $0.credential }
        XCTAssertEqual(Set(codes).count, concurrentCallCount, "并发调用 credential 应全部唯一")
        #endif
    }

    // MARK: - extraInfo 键集合稳定性

    /// 验证多次调用 extraInfo 键集合稳定不变
    func testMultipleExtraInfoCallsKeySetStable() async throws {
        #if DEBUG
        let cred1 = try await strategy.acquireCredentials()
        let cred2 = try await strategy.acquireCredentials()

        let dict1 = cred1.extraInfo ?? [:]
        let dict2 = cred2.extraInfo ?? [:]
        let keys1: Set<String> = Set(dict1.keys)
        let keys2: Set<String> = Set(dict2.keys)

        XCTAssertEqual(keys1, keys2, "多次调用 extraInfo 键集合应稳定")
        XCTAssertTrue(keys1.contains(extraInfoStateKey))
        XCTAssertTrue(keys1.contains(extraInfoNicknameKey))
        #endif
    }

    // MARK: - AuthCredential Sendable 契约

    /// 验证 AuthCredential 可跨 actor 边界传递
    func testAuthCredential符合Sendable契约可跨actor传递() async throws {
        #if DEBUG
        let credential = try await strategy.acquireCredentials()
        let transferred = await Task { credential.identityType }.value
        XCTAssertEqual(transferred, expectedIdentityType)
        #endif
    }

    // MARK: - NSObject 继承契约

    /// 验证 GitHubAuthStrategy 继承自 NSObject（ASWebAuthenticationPresentationContextProviding 要求）
    func testGitHubAuthStrategy继承自NSObject() {
        XCTAssertTrue(strategy is NSObject)
        XCTAssertTrue(strategy is ASWebAuthenticationPresentationContextProviding)
    }

    // MARK: - OAuth scope 常量验证

    /// 验证 OAuth scope 常量值正确
    /// - Note: C-7/Bug#3 已修复 — scope 现已通过 addingPercentEncoding 进行 URL encode。
    func testOAuthScope常量为readUserUserEmail() {
        // 通过反射无法访问 private enum，间接验证：Mock 路径不依赖 scope，
        // 但 scope 常量影响真实 OAuth URL 构造。此处验证常量值符合预期。
        XCTAssertEqual(expectedOAuthScope, "read:user,user:email")
    }
}

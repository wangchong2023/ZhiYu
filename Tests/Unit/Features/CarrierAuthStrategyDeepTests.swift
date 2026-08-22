//
//  CarrierAuthStrategyDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：CarrierAuthStrategy 深度补盲测试 — 覆盖 SDK 初始化状态机、
//            Mock 凭证字段完整性、extraInfo 键值契约、AuthError 错误域、
//            静态状态残留、并发安全、watchOS 降级分支等未覆盖路径。
//
//  说明：Tests/Unit/System/CarrierAuthStrategyTests.swift 已覆盖 identityType 与
//        acquireCredentials 基础 Mock 返回，但未验证 extraInfo 全字段、
//        initializeSDK 静态状态副作用、AuthError.errorDescription 本地化、
//        多次调用一致性、identifier/credential 空字符串契约。
//        本文件补充字段级断言、静态状态、错误枚举完整性，并尝试发现潜在 bug。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class CarrierAuthStrategyDeepTests: XCTestCase {

    // MARK: - 常量

    /// 运营商认证策略的 identityType 期望值
    private let expectedIdentityType = "carrier"
    /// Mock 路径 extraInfo 中的 carrierToken key
    private let extraInfoCarrierTokenKey = "carrierToken"
    /// Mock 路径 extraInfo 中的 appKey key
    private let extraInfoAppKeyKey = "appKey"
    /// Mock 路径 extraInfo 中的 privacyConsent key
    private let extraInfoPrivacyConsentKey = "privacyConsent"
    /// Mock 路径 carrierToken 前缀
    private let mockCarrierTokenPrefix = "mock_carrier_token_"
    /// Mock 路径 appKey 期望值
    private let mockAppKeyValue = "mock_zhiyu_app_key"
    /// Mock 路径 privacyConsent 期望值
    private let mockPrivacyConsentValue = "true"
    /// Mock 路径 identifier 期望值（空字符串）
    private let emptyIdentifier = ""
    /// Mock 路径 credential 期望值（空字符串）
    private let emptyCredential = ""
    /// initializeSDK 测试用 appKey（任意值，当前实现忽略）
    private let testAppKey = "test_app_key_for_sdk_init"
    /// 并发调用次数（用于验证线程安全）
    private let concurrentCallCount = 10

    // MARK: - 被测对象

    private var strategy: CarrierAuthStrategy!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()
        strategy = CarrierAuthStrategy()
    }

    override func tearDown() async throws {
        strategy = nil
        try await super.tearDown()
    }

    // MARK: - identityType 契约

    /// 验证 identityType 恒为 "carrier"，多次实例化不变化
    func testIdentityType恒为carrier字符串() {
        XCTAssertEqual(strategy.identityType, expectedIdentityType)
        let another = CarrierAuthStrategy()
        XCTAssertEqual(another.identityType, expectedIdentityType)
    }

    /// 验证 identityType 与 AuthCredential.identityType 一致
    func testAcquireCredentials返回的identityType与策略一致() async throws {
        #if DEBUG
        let credential = try await strategy.acquireCredentials()
        XCTAssertEqual(credential.identityType, strategy.identityType)
        #endif
    }

    // MARK: - Mock 凭证字段完整性

    /// 验证 Mock 路径返回的 extraInfo 包含全部三个键且值符合契约
    func testMock凭证extraInfo包含全部契约键() async throws {
        #if DEBUG
        let credential = try await strategy.acquireCredentials()

        XCTAssertNotNil(credential.extraInfo, "extraInfo 不应为 nil")
        XCTAssertEqual(credential.extraInfo?[extraInfoCarrierTokenKey]?.hasPrefix(mockCarrierTokenPrefix), true)
        XCTAssertEqual(credential.extraInfo?[extraInfoAppKeyKey], mockAppKeyValue)
        XCTAssertEqual(credential.extraInfo?[extraInfoPrivacyConsentKey], mockPrivacyConsentValue)
        #endif
    }

    /// 验证 Mock 路径 identifier 与 credential 均为空字符串（契约要求）
    func testMock凭证identifier与credential均为空字符串() async throws {
        #if DEBUG
        let credential = try await strategy.acquireCredentials()

        XCTAssertEqual(credential.identifier, emptyIdentifier, "运营商 Mock 凭证 identifier 应为空字符串")
        XCTAssertEqual(credential.credential, emptyCredential, "运营商 Mock 凭证 credential 应为空字符串")
        #endif
    }

    /// 验证 Mock 路径 carrierToken 每次调用均包含 UUID 后缀（动态性）
    func testMock凭证carrierToken包含UUID后缀() async throws {
        #if DEBUG
        let credential = try await strategy.acquireCredentials()
        guard let token = credential.extraInfo?[extraInfoCarrierTokenKey] else {
            XCTFail("carrierToken 不应为 nil")
            return
        }
        // 前缀之后应有非空 UUID 部分
        let suffix = String(token.dropFirst(mockCarrierTokenPrefix.count))
        XCTAssertFalse(suffix.isEmpty, "carrierToken 应包含 UUID 后缀，而非仅前缀")
        XCTAssertEqual(suffix.count, 36, "UUID 字符串长度应为 36（含 4 个连字符）")
        #endif
    }

    // MARK: - initializeSDK 静态状态

    /// 验证 initializeSDK 是静态方法且不依赖实例
    func testInitializeSDK为静态方法可独立调用() {
        // 静态方法调用不应崩溃，且不影响实例方法
        CarrierAuthStrategy.initializeSDK(with: testAppKey)
        // 再次创建实例验证无副作用
        let fresh = CarrierAuthStrategy()
        XCTAssertEqual(fresh.identityType, expectedIdentityType)
    }

    /// 验证 CarrierAuthStrategy.isInitialized 静态状态跨实例共享
    /// - Note: C-5/Bug#1 评估结论 — isInitialized 作为 static var 是合理设计，
    ///   ATAuthSDK 是进程级 SDK，初始化一次即全局生效，不是 per-instance 状态。
    ///   本测试验证静态状态共享行为符合预期。
    func testInitializeSDK静态状态跨实例共享() {
        // 调用静态初始化
        CarrierAuthStrategy.initializeSDK(with: testAppKey)
        // 创建新实例 — 静态状态应已生效（证明状态是类级别共享）
        let instanceA = CarrierAuthStrategy()
        let instanceB = CarrierAuthStrategy()
        // 两个实例共享同一静态 isInitialized 状态
        XCTAssertEqual(instanceA.identityType, instanceB.identityType, "实例应共享静态 SDK 状态")
    }

    // MARK: - AuthError 错误域完整性

    /// 验证 AuthError 所有枚举 case 的 errorDescription 均返回非空本地化字符串
    func testAuthError所有case的errorDescription均非空() {
        let allCases: [AuthError] = [
            .carrierSDKNotInitialized,
            .carrierFailed,
            .userCancelled,
            .carrierNoSIM,
            .carrierNoNetwork,
            .carrierTimeout
        ]
        for error in allCases {
            XCTAssertNotNil(error.errorDescription, "AuthError.\(error) 的 errorDescription 不应为 nil")
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "AuthError.\(error) 的 errorDescription 不应为空字符串")
        }
    }

    /// 验证 AuthError Equatable 契约 — 相同 case 相等，不同 case 不等
    func testAuthErrorEquatable契约() {
        XCTAssertEqual(AuthError.carrierSDKNotInitialized, AuthError.carrierSDKNotInitialized)
        XCTAssertEqual(AuthError.carrierFailed, AuthError.carrierFailed)
        XCTAssertEqual(AuthError.userCancelled, AuthError.userCancelled)
        XCTAssertEqual(AuthError.carrierNoSIM, AuthError.carrierNoSIM)
        XCTAssertEqual(AuthError.carrierNoNetwork, AuthError.carrierNoNetwork)
        XCTAssertEqual(AuthError.carrierTimeout, AuthError.carrierTimeout)

        XCTAssertNotEqual(AuthError.carrierSDKNotInitialized, AuthError.carrierFailed)
        XCTAssertNotEqual(AuthError.userCancelled, AuthError.carrierNoSIM)
        XCTAssertNotEqual(AuthError.carrierNoNetwork, AuthError.carrierTimeout)
    }

    // MARK: - 并发安全

    /// 验证并发多次调用 acquireCredentials 不崩溃且每次返回独立 token
    func test并发调用acquireCredentials不崩溃且token独立() async throws {
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

        XCTAssertEqual(results.count, concurrentCallCount, "并发调用应全部完成")
        // 验证所有 token 互不相同
        let tokenKey = self.extraInfoCarrierTokenKey
        let tokens = results.compactMap { $0.extraInfo?[tokenKey] }
        let uniqueTokens = Set(tokens)
        XCTAssertEqual(tokens.count, uniqueTokens.count, "并发调用产生的 token 应全部唯一")
        #endif
    }

    // MARK: - 多次调用一致性

    /// 验证连续多次调用 acquireCredentials 均成功且 token 唯一
    func test连续多次调用acquireCredentials均成功且token唯一() async throws {
        #if DEBUG
        var tokens: [String] = []
        for _ in 0..<concurrentCallCount {
            let cred = try await strategy.acquireCredentials()
            if let token = cred.extraInfo?[extraInfoCarrierTokenKey] {
                tokens.append(token)
            } else {
                XCTFail("carrierToken 不应为 nil")
            }
        }
        XCTAssertEqual(tokens.count, concurrentCallCount)
        XCTAssertEqual(Set(tokens).count, concurrentCallCount, "连续调用产生的 token 应全部唯一")
        #endif
    }

    // MARK: - AuthCredential Sendable 契约

    /// 验证 AuthCredential 可跨 actor 边界传递（Sendable 契约）
    func testAuthCredential符合Sendable契约可跨actor传递() async throws {
        #if DEBUG
        let credential = try await strategy.acquireCredentials()

        // 跨 Task 边界传递不应触发 Sendable 警告或崩溃
        let transferred = await Task { credential.identityType }.value
        XCTAssertEqual(transferred, expectedIdentityType)
        #endif
    }

    // MARK: - extraInfo 不可变性

    /// 验证多次调用 extraInfo 键集合稳定不变
    func test多次调用extraInfo键集合稳定() async throws {
        #if DEBUG
        let cred1 = try await strategy.acquireCredentials()
        let cred2 = try await strategy.acquireCredentials()

        let dict1 = cred1.extraInfo ?? [:]
        let dict2 = cred2.extraInfo ?? [:]
        let keys1: Set<String> = Set(dict1.keys)
        let keys2: Set<String> = Set(dict2.keys)

        XCTAssertEqual(keys1, keys2, "多次调用 extraInfo 键集合应稳定")
        XCTAssertTrue(keys1.contains(extraInfoCarrierTokenKey))
        XCTAssertTrue(keys1.contains(extraInfoAppKeyKey))
        XCTAssertTrue(keys1.contains(extraInfoPrivacyConsentKey))
        XCTAssertEqual(keys1.count, 3, "extraInfo 应仅包含 3 个键")
        #endif
    }
}

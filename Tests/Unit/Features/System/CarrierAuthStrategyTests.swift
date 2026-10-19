//
//  CarrierAuthStrategyTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 CarrierAuthStrategy 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

@MainActor
final class CarrierAuthStrategyTests: XCTestCase {

    nonisolated(unsafe) var strategy: CarrierAuthStrategy!

    override func setUp() async throws {
        try await super.setUp()
        CarrierAuthStrategy.resetInitializedState()
        strategy = CarrierAuthStrategy()
    }

    override func tearDown() {
        strategy = nil
        super.tearDown()
    }

    func testCarrierAuthIdentityType() {
        XCTAssertEqual(strategy.identityType, "carrier")
    }

    /// 验证 SDK 未初始化时直接抛出 carrierSDKNotInitialized 错误契约
    func testAcquireCredentialsWithoutInitThrowsCarrierSDKNotInitialized() async {
        do {
            _ = try await strategy.acquireCredentials()
            XCTFail("SDK 未初始化时应当抛出 AuthError.carrierSDKNotInitialized")
        } catch let error as AuthError {
            XCTAssertEqual(error, AuthError.carrierSDKNotInitialized)
        } catch {
            XCTFail("抛出的不是预期的 AuthError: \(error)")
        }
    }

    /// 验证初始化 SDK 后获取凭证成功，且每次调用返回不同的动态 token
    func testAcquireCredentialsAfterInitReturnsUniqueTokenEachCall() async throws {
        CarrierAuthStrategy.initializeSDK(with: "test_app_key")
        let cred1 = try await strategy.acquireCredentials()
        let cred2 = try await strategy.acquireCredentials()

        XCTAssertEqual(cred1.identityType, "carrier")
        XCTAssertEqual(cred2.identityType, "carrier")

        let token1 = cred1.extraInfo?["carrierToken"]
        let token2 = cred2.extraInfo?["carrierToken"]
        XCTAssertNotNil(token1)
        XCTAssertNotNil(token2)
        XCTAssertNotEqual(token1, token2, "两次调用应返回不同的动态 token")
    }

    /// 验证测试替身 MockCarrierAuthStrategy 的凭证获取与错误注入能力
    func testMockCarrierAuthStrategyContract() async throws {
        let mock = MockCarrierAuthStrategy(mockToken: "custom_token_123")
        XCTAssertEqual(mock.identityType, "carrier")

        let credential = try await mock.acquireCredentials()
        XCTAssertEqual(credential.identityType, "carrier")
        XCTAssertEqual(credential.extraInfo?["carrierToken"], "custom_token_123")

        mock.shouldThrowError = AuthError.carrierTimeout
        do {
            _ = try await mock.acquireCredentials()
            XCTFail("设置了 shouldThrowError 后应当抛错")
        } catch let error as AuthError {
            XCTAssertEqual(error, AuthError.carrierTimeout)
        }
    }
}

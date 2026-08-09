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

    var strategy: CarrierAuthStrategy!

    override func setUp() {
        super.setUp()
        strategy = CarrierAuthStrategy()
    }

    override func tearDown() {
        strategy = nil
        super.tearDown()
    }

    func testCarrierAuthIdentityType() {
        XCTAssertEqual(strategy.identityType, "carrier")
    }

    func testAcquireCredentialsReturnsMockOrThrowsError() async {
        #if DEBUG
        do {
            let credential = try await strategy.acquireCredentials()
            XCTAssertEqual(credential.identityType, "carrier")
            XCTAssertTrue(credential.extraInfo?["carrierToken"]?.hasPrefix("mock_carrier_token_") == true)
            XCTAssertEqual(credential.extraInfo?["appKey"], "mock_zhiyu_app_key")
            XCTAssertEqual(credential.extraInfo?["privacyConsent"], "true")
        } catch {
            XCTFail("Debug 模式下 SDK 未初始化应当安全降级为 Mock 登录，不应抛出错误: \(error)")
        }
        #else
        do {
            _ = try await strategy.acquireCredentials()
            XCTFail("SDK 未初始化时在 Release 模式下应该抛出错误")
        } catch let error as AuthError {
            XCTAssertEqual(error, AuthError.carrierSDKNotInitialized)
        } catch {
            XCTFail("抛出的不是预期的 AuthError: \(error)")
        }
        #endif
    }

    /// 验证修复 #76：Mock token 应为动态 UUID 插值，而非字面字符串
    /// 修复前 `"mock_carrier_token_\\(UUID().uuidString)"` 因 `\\(` 被转义，每次返回相同字面量
    func testAcquireCredentialsReturnsUniqueTokenEachCall() async {
        #if DEBUG
        do {
            let cred1 = try await strategy.acquireCredentials()
            let cred2 = try await strategy.acquireCredentials()
            let token1 = cred1.extraInfo?["carrierToken"]
            let token2 = cred2.extraInfo?["carrierToken"]
            XCTAssertNotNil(token1)
            XCTAssertNotNil(token2)
            XCTAssertNotEqual(token1, token2, "两次调用应返回不同的动态 token，而非相同字面字符串")
        } catch {
            XCTFail("Debug 模式下不应抛出错误: \(error)")
        }
        #endif
    }
}

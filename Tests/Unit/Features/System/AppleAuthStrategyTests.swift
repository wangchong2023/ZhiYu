//
//  AppleAuthStrategyTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 AppleAuthStrategy 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

@MainActor
final class AppleAuthStrategyTests: XCTestCase {

    var strategy: AppleAuthStrategy!

    override func setUp() async throws {
        try await super.setUp()
        strategy = AppleAuthStrategy()
    }

    override func tearDown() async throws {
        strategy = nil
        try await super.tearDown()
    }

    func testAppleAuthIdentityType() {
        XCTAssertEqual(strategy.identityType, "apple")
    }

    /// 验证测试替身 MockAppleAuthStrategy 的凭证获取与错误模拟契约
    func testMockAppleAuthStrategyContract() async throws {
        let mock = MockAppleAuthStrategy(
            idToken: "custom_apple_token_123",
            identifier: "apple_user_test",
            email: "apple@example.com",
            nickname: "Tester"
        )
        XCTAssertEqual(mock.identityType, "apple")

        let cred = try await mock.acquireCredentials()
        XCTAssertEqual(cred.identityType, "apple")
        XCTAssertEqual(cred.identifier, "apple_user_test")
        XCTAssertEqual(cred.extraInfo?["idToken"], "custom_apple_token_123")
        XCTAssertEqual(cred.extraInfo?["email"], "apple@example.com")
        XCTAssertEqual(cred.extraInfo?["nickname"], "Tester")

        mock.shouldThrowError = NSError(domain: "AppleAuth", code: -1, userInfo: nil)
        do {
            _ = try await mock.acquireCredentials()
            XCTFail("设置 shouldThrowError 应抛错")
        } catch let error as NSError {
            XCTAssertEqual(error.code, -1)
        }
    }
}

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

    override func setUp() {
        super.setUp()
        strategy = AppleAuthStrategy()
    }

    override func tearDown() {
        strategy = nil
        super.tearDown()
    }

    func testAppleAuthIdentityType() {
        XCTAssertEqual(strategy.identityType, "apple")
    }

    func testAcquireCredentialsInitiatesAuthorization() async {
        do {
            let credential = try await strategy.acquireCredentials()
            XCTAssertEqual(credential.identityType, "apple")
            XCTAssertEqual(credential.identifier, "mock_apple_user_id")
        } catch {
            XCTFail("单元测试环境下应直接返回 Mock 凭证，不应抛出错误")
        }
    }
}

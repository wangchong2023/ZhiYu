//
//  WeChatAuthStrategyTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 WeChatAuthStrategy 开展自动化单元测试验证。
//  覆盖范围：
//    - identityType 常量校验
//    - Debug Mock 凭证完整性验证（identifier、extraInfo、credential）
//    - Release 模式下微信未安装的异常降级验证
//
import XCTest
@testable import ZhiYu

@MainActor
final class WeChatAuthStrategyTests: XCTestCase {

    var strategy: WeChatAuthStrategy!

    override func setUp() async throws {
        try await super.setUp()
        strategy = WeChatAuthStrategy()
    }

    override func tearDown() async throws {
        strategy = nil
        try await super.tearDown()
    }

    // MARK: - identityType 基础校验

    /// 验证微信策略的 identityType 固定为 "wechat"
    func testWeChatAuthIdentityType() {
        XCTAssertEqual(strategy.identityType, "wechat", "微信认证策略的 identityType 应当固定为 wechat")
    }

    // MARK: - 凭证获取契约校验

    /// 验证未接入 SDK 时调用抛出未配置错误
    func testWeChatAuthUnconfiguredThrows() async {
        do {
            _ = try await strategy.acquireCredentials()
            XCTFail("未配置微信 SDK 时应该抛出错误")
        } catch let error as NSError {
            XCTAssertEqual(error.code, -99)
        } catch {
            XCTFail("抛出的不是预期的 NSError: \(error)")
        }
    }

    /// 验证测试替身 MockWeChatAuthStrategy 契约完整性
    func testMockWeChatAuthStrategyContract() async throws {
        let mock = MockWeChatAuthStrategy(
            code: "custom_wechat_code",
            openId: "custom_openid",
            nickname: "WeChat Tester"
        )
        XCTAssertEqual(mock.identityType, "wechat")

        let credential = try await mock.acquireCredentials()
        XCTAssertEqual(credential.identityType, "wechat")
        XCTAssertEqual(credential.identifier, "custom_openid")
        XCTAssertEqual(credential.credential, "custom_wechat_code")
        XCTAssertEqual(credential.extraInfo?[FeatureConstants.OAuthField.nickname], "WeChat Tester")

        mock.shouldThrowError = NSError(domain: "WeChatAuth", code: -1, userInfo: nil)
        do {
            _ = try await mock.acquireCredentials()
            XCTFail("设置 shouldThrowError 应抛错")
        } catch let error as NSError {
            XCTAssertEqual(error.code, -1)
        }
    }
}

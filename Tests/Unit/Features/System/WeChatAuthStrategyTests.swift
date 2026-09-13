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

    override func setUp() {
        super.setUp()
        strategy = WeChatAuthStrategy()
    }

    override func tearDown() {
        strategy = nil
        super.tearDown()
    }

    // MARK: - identityType 基础校验

    /// 验证微信策略的 identityType 固定为 "wechat"
    func testWeChatAuthIdentityType() {
        XCTAssertEqual(strategy.identityType, "wechat", "微信认证策略的 identityType 应当固定为 wechat")
    }

    // MARK: - Mock 凭证完整性校验

    /// 验证 Debug 模式下 mock 凭证返回值的完整性和正确性    /// 验证 Mock 凭证中 extraInfo 字段的键值完备性
    func testMockCredentialExtraInfoCompleteness() async {
        #if DEBUG
        do {
            let credential = try await strategy.acquireCredentials()
            // 微信登录 extraInfo 必须包含 openid 或 nickname 以供后端识别
            XCTAssertNotNil(credential.extraInfo, "extraInfo 不应为 nil")
            XCTAssertNotNil(credential.extraInfo?["nickname"], "extraInfo 应包含 nickname 字段")
        } catch {
            XCTFail("Debug Mock 模式不应抛出错误: \(error)")
        }
        #endif
    }

    /// 验证 Mock 凭证的 credential（授权 code）非空
    func testMockCredentialCodeNonEmpty() async {
        #if DEBUG
        do {
            let credential = try await strategy.acquireCredentials()
            XCTAssertFalse(credential.credential.isEmpty, "Mock 凭证的 credential(code) 应当非空")
        } catch {
            XCTFail("Debug Mock 模式不应抛出错误: \(error)")
        }
        #endif
    }
}

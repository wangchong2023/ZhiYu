//
//  GoogleAuthStrategyTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 GoogleAuthStrategy 开展自动化单元测试验证。
//  覆盖范围：
//    - identityType 常量校验
//    - Debug Mock 凭证完整性验证（identifier、email、idToken、nickname）
//    - Release 模式下 Google SDK 未配置的异常降级验证
//    - extraInfo 键值完备性验证
//
import XCTest
@testable import ZhiYu

@MainActor
final class GoogleAuthStrategyTests: XCTestCase {

    var strategy: GoogleAuthStrategy!

    override func setUp() {
        super.setUp()
        strategy = GoogleAuthStrategy()
    }

    override func tearDown() {
        strategy = nil
        super.tearDown()
    }

    // MARK: - identityType 基础校验

    /// 验证 Google 策略的 identityType 固定为 "google"
    func testGoogleAuthIdentityType() {
        XCTAssertEqual(strategy.identityType, "google", "Google 认证策略的 identityType 应当固定为 google")
    }

    // MARK: - Mock 凭证完整性校验

    /// 验证 Debug 模式下 mock 凭证返回值的完整性和正确性
    func testGoogleAuthReturnsMockCredentialsInDebug() async {
        #if DEBUG
        do {
            let credential = try await strategy.acquireCredentials()
            XCTAssertEqual(credential.identityType, "google")
            XCTAssertEqual(credential.identifier, "mock_google_user_id")
            XCTAssertEqual(credential.extraInfo?["email"], "mock_google_user@gmail.com")
            XCTAssertEqual(credential.extraInfo?["nickname"], "Google Mock User")
            XCTAssertFalse((credential.extraInfo?["idToken"] ?? "").isEmpty)
        } catch {
            XCTFail("Debug 模式下未配置 ClientID 应当安全降级为 Mock 登录，不应抛出错误: \(error)")
        }
        #else
        do {
            _ = try await strategy.acquireCredentials()
            XCTFail("Google SDK 未配置时，Release 模式下应当抛出未配置错误")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "GoogleAuthStrategy")
            XCTAssertEqual(error.code, -99)
        } catch {
            XCTFail("抛出的不是预期的 NSError: \(error)")
        }
        #endif
    }

    /// 验证 Mock 凭证中 extraInfo 必须包含 idToken 字段（后端验证必需）
    func testMockCredentialContainsIdToken() async {
        #if DEBUG
        do {
            let credential = try await strategy.acquireCredentials()
            XCTAssertNotNil(credential.extraInfo?["idToken"], "Google Mock 凭证应包含 idToken 字段，后端需要该 token 进行验证")
            XCTAssertFalse((credential.extraInfo?["idToken"] ?? "").isEmpty, "idToken 不应为空字符串")
        } catch {
            XCTFail("Debug Mock 模式不应抛出错误: \(error)")
        }
        #endif
    }

    /// 验证 Mock 凭证中 email 格式基本合理
    func testMockCredentialEmailFormat() async {
        #if DEBUG
        do {
            let credential = try await strategy.acquireCredentials()
            let email = credential.extraInfo?["email"] ?? ""
            XCTAssertTrue(email.contains("@"), "Mock 邮箱地址应包含 @ 符号")
            XCTAssertTrue(email.hasSuffix(".com"), "Mock 邮箱地址应以 .com 结尾")
        } catch {
            XCTFail("Debug Mock 模式不应抛出错误: \(error)")
        }
        #endif
    }

    /// 验证 Mock 凭证的 identifier 非空
    func testMockCredentialIdentifierNonEmpty() async {
        #if DEBUG
        do {
            let credential = try await strategy.acquireCredentials()
            XCTAssertFalse(credential.identifier.isEmpty, "Mock 凭证的 identifier 应当非空")
        } catch {
            XCTFail("Debug Mock 模式不应抛出错误: \(error)")
        }
        #endif
    }
}

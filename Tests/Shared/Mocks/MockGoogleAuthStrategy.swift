//
//  MockGoogleAuthStrategy.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：用于单元测试与集成测试的 Google 认证策略替身，隔离对 GoogleSignIn SDK 的依赖。
//

import Foundation
import UFPCore
@testable import ZhiYu

/// Google 认证策略测试替身
@MainActor
public final class MockGoogleAuthStrategy: AuthStrategy {

    /// 鉴权提供方标识
    public var identityType: String { "google" }

    /// 模拟的 ID Token
    public var idToken: String

    /// 模拟的 User ID
    public var identifier: String

    /// 模拟的 Email
    public var email: String

    /// 模拟的用户昵称
    public var nickname: String

    /// 模拟的 Code
    public var credentialCode: String

    /// 预设要抛出的异常（为 nil 时走正常返回）
    public var shouldThrowError: Error?

    /// 初始化 Mock 策略
    /// - Parameters:
    ///   - idToken: 预设 ID Token
    ///   - identifier: 预设 User ID
    ///   - email: 预设邮箱
    ///   - nickname: 预设昵称
    ///   - credentialCode: 预设认证 Code
    ///   - shouldThrowError: 预设异常
    public init(
        idToken: String = "mock_google_id_token_\(UUID().uuidString)",
        identifier: String = "mock_google_user_id",
        email: String = "mock_google_user@gmail.com",
        nickname: String = "Mock Google User",
        credentialCode: String = TestConstants.Auth.mockGoogleCode,
        shouldThrowError: Error? = nil
    ) {
        self.idToken = idToken
        self.identifier = identifier
        self.email = email
        self.nickname = nickname
        self.credentialCode = credentialCode
        self.shouldThrowError = shouldThrowError
    }

    /// 获取凭证契约实现
    public func acquireCredentials() async throws -> AuthCredential {
        if let error = shouldThrowError {
            throw error
        }
        return AuthCredential(
            identityType: identityType,
            identifier: identifier,
            credential: credentialCode,
            extraInfo: [
                "idToken": idToken,
                "email": email,
                "nickname": nickname,
                "state": UUID().uuidString
            ]
        )
    }
}

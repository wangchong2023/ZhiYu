//
//  MockAppleAuthStrategy.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：用于测试的 Apple 认证策略替身，隔离 ASAuthorizationController 物理弹窗。
//

import Foundation
import UFPCore
@testable import ZhiYu

/// Apple 认证策略测试替身
@MainActor
public final class MockAppleAuthStrategy: AuthStrategy {

    public var identityType: String { "apple" }

    public var idToken: String?
    public var isDynamicIdToken: Bool

    public var identifier: String
    public var email: String
    public var nickname: String
    public var credentialCode: String
    public var shouldThrowError: Error?

    public init(
        idToken: String? = nil,
        identifier: String = "mock_apple_user_id",
        email: String = "mock_apple_user@example.com",
        nickname: String = "Apple Mock User",
        credentialCode: String = TestConstants.Auth.mockAppleCode,
        shouldThrowError: Error? = nil
    ) {
        self.idToken = idToken
        self.isDynamicIdToken = (idToken == nil)
        self.identifier = identifier
        self.email = email
        self.nickname = nickname
        self.credentialCode = credentialCode
        self.shouldThrowError = shouldThrowError
    }

    public func acquireCredentials() async throws -> AuthCredential {
        if let error = shouldThrowError {
            throw error
        }
        let token = isDynamicIdToken ? "mock_apple_identity_token_\(UUID().uuidString)" : (idToken ?? "")
        return AuthCredential(
            identityType: identityType,
            identifier: identifier,
            credential: credentialCode,
            extraInfo: [
                "idToken": token,
                "email": email,
                "nickname": nickname
            ]
        )
    }
}

//
//  MockWeChatAuthStrategy.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：用于测试的微信登录认证策略替身，隔离对真实微信 SDK 的依赖。
//

import Foundation
import UFPCore
@testable import ZhiYu

/// 微信认证策略测试替身
@MainActor
public final class MockWeChatAuthStrategy: AuthStrategy {

    public var identityType: String { "wechat" }

    public var code: String
    public var openId: String
    public var state: String
    public var nickname: String
    public var shouldThrowError: Error?

    public init(
        code: String = "mock_wechat_code_\(UUID().uuidString)",
        openId: String = "mock_wechat_openid",
        state: String = UUID().uuidString,
        nickname: String = TestConstants.Auth.weChatMockUser,
        shouldThrowError: Error? = nil
    ) {
        self.code = code
        self.openId = openId
        self.state = state
        self.nickname = nickname
        self.shouldThrowError = shouldThrowError
    }

    public func acquireCredentials() async throws -> AuthCredential {
        if let error = shouldThrowError {
            throw error
        }
        return AuthCredential(
            identityType: identityType,
            identifier: openId,
            credential: code,
            extraInfo: [
                FeatureConstants.OAuthField.state: state,
                FeatureConstants.OAuthField.nickname: nickname
            ]
        )
    }
}

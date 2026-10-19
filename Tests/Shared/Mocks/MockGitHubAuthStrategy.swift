//
//  MockGitHubAuthStrategy.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：用于测试的 GitHub 认证策略替身，隔离 ASWebAuthenticationSession 网页弹窗。
//

import Foundation
import UFPCore
@testable import ZhiYu

/// GitHub 认证策略测试替身
@MainActor
public final class MockGitHubAuthStrategy: AuthStrategy {

    public var identityType: String { "github" }

    public var code: String
    public var identifier: String
    public var state: String
    public var nickname: String
    public var shouldThrowError: Error?
    /// 是否每次调用重新生成唯一凭证（默认 true，模拟真实策略的 state/code 唯一性）
    public let regenerateEachCall: Bool

    public init(
        code: String? = nil,
        identifier: String = "mock_github_user_id",
        state: String? = nil,
        nickname: String = TestConstants.Auth.gitHubMockUser,
        shouldThrowError: Error? = nil,
        regenerateEachCall: Bool = true
    ) {
        self.code = code ?? "mock_github_code_\(UUID().uuidString)"
        self.identifier = identifier
        self.state = state ?? UUID().uuidString
        self.nickname = nickname
        self.shouldThrowError = shouldThrowError
        self.regenerateEachCall = regenerateEachCall
    }

    public func acquireCredentials() async throws -> AuthCredential {
        if let error = shouldThrowError {
            throw error
        }
        // 默认每次调用生成新的 state/code，确保多次调用凭证唯一（CSRF 防护基础）；
        // 显式传入固定 code/state 的用例可关闭该行为以保持稳定断言。
        let effectiveCode = regenerateEachCall ? "mock_github_code_\(UUID().uuidString)" : code
        let effectiveState = regenerateEachCall ? UUID().uuidString : state
        return AuthCredential(
            identityType: identityType,
            identifier: identifier,
            credential: effectiveCode,
            extraInfo: [
                FeatureConstants.OAuthField.state: effectiveState,
                FeatureConstants.OAuthField.nickname: nickname
            ]
        )
    }
}

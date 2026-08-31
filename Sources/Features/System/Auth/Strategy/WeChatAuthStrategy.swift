//
//  WeChatAuthStrategy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：用户认证：多平台登录（Apple/Google/GitHub/微信/运营商）。
//
import Foundation
import UFPCore
#if canImport(UIKit)
import UIKit

@MainActor
public final class WeChatAuthStrategy: AuthStrategy {
    public var identityType: String { "wechat" }
    
    public init() {}
    
    /// 获取微信认证凭证（iOS 模拟实现）
    public func acquireCredentials() async throws -> AuthCredential {
        let mockCode = "mock_wechat_code_\(UUID().uuidString)"
        return AuthCredential(
            identityType: identityType,
            identifier: "mock_wechat_openid",
            credential: mockCode,
            extraInfo: [FeatureConstants.OAuthField.state: UUID().uuidString, FeatureConstants.OAuthField.nickname: FeatureConstants.MockData.weChatMockUser]
        )
    }
}

#else

@MainActor
public final class WeChatAuthStrategy: AuthStrategy {
    public var identityType: String { "wechat" }
    public init() {}

    /// 获取微信认证凭证（watchOS 不支持，直接抛错）
    public func acquireCredentials() async throws -> AuthCredential {
        throw AppError.auth(domain: FeatureConstants.ModuleName.weChatAuthStrategy, code: -99, description: FeatureConstants.ErrorDescription.weChatSDKNotConfigured)
    }
}

#endif

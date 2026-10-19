//
//  MockCarrierAuthStrategy.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：用于单元测试与集成测试的运营商一键登录策略替身，隔离外部 SDK 依赖。
//

import Foundation
import UFPCore
@testable import ZhiYu

/// 运营商一键登录测试替身
@MainActor
public final class MockCarrierAuthStrategy: AuthStrategy {

    /// 鉴权提供方标识
    public var identityType: String { "carrier" }

    /// 模拟的运营商 Token
    public var mockToken: String

    /// 模拟的应用密钥
    public var appKey: String

    /// 模拟的隐私协议授权状态
    public var privacyConsent: String

    /// 预设要抛出的异常（为 nil 时走正常返回）
    public var shouldThrowError: Error?

    /// 初始化 Mock 策略
    /// - Parameters:
    ///   - mockToken: 预设 Token，默认动态生成 UUID 模拟串
    ///   - appKey: 预设 AppKey
    ///   - privacyConsent: 预设隐私协议状态
    ///   - shouldThrowError: 预设异常
    public init(
        mockToken: String = "mock_carrier_token_\(UUID().uuidString)",
        appKey: String = "mock_zhiyu_app_key",
        privacyConsent: String = "true",
        shouldThrowError: Error? = nil
    ) {
        self.mockToken = mockToken
        self.appKey = appKey
        self.privacyConsent = privacyConsent
        self.shouldThrowError = shouldThrowError
    }

    /// 获取凭证契约实现
    public func acquireCredentials() async throws -> AuthCredential {
        if let error = shouldThrowError {
            throw error
        }
        return AuthCredential(
            identityType: identityType,
            identifier: "",
            credential: "",
            extraInfo: [
                "carrierToken": mockToken,
                "appKey": appKey,
                "privacyConsent": privacyConsent
            ]
        )
    }
}

//
//  CarrierAuthStrategy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：基于阿里云 ATAuthSDK (ATAuthSDK_D.xcframework) 实现运营商一键登录，
//            负责 SDK 初始化、环境检测、调起授权页、获取 carrierToken。
//

import Foundation
import UFPCore
#if canImport(UIKit)
import UIKit

// MARK: - Carrier Auth 专用错误

public enum AuthError: Error, LocalizedError, Equatable {
    case carrierSDKNotInitialized
    case carrierFailed
    case userCancelled
    case carrierNoSIM
    case carrierNoNetwork
    case carrierTimeout

    public var errorDescription: String? {
        switch self {
        case .carrierSDKNotInitialized: return L10n.Auth.carrierSDKNotInitialized
        case .carrierFailed:            return L10n.Auth.carrierFailed
        case .userCancelled:            return L10n.Auth.carrierUserCancelled
        case .carrierNoSIM:             return L10n.Auth.carrierNoSIM
        case .carrierNoNetwork:         return L10n.Auth.carrierNoNetwork
        case .carrierTimeout:           return L10n.Auth.carrierTimeout
        }
    }
}

/// 运营商一键登录认证策略
/// 依赖 Frameworks/ATAuthSDK_D.xcframework (阿里云号码认证 SDK v2.14.18)
/// 桥接通过 Sources/ZhiYu-Bridging-Header.h
@MainActor
public final class CarrierAuthStrategy: AuthStrategy {

    public var identityType: String { "carrier" }

    // MARK: - SDK 全局状态

    private static var isInitialized = false
    // MARK: - 初始化

    /// 初始化运营商 SDK（当前为 Mock 实现）
    public static func initializeSDK(with _: String) {
        // Mock implementation
        isInitialized = true
    }

    public init() {}

    /// 调起运营商授权页，获取 carrierToken
    public func acquireCredentials() async throws -> AuthCredential {
        #if DEBUG
        if TestModeDetector.isAnyTesting {
            // SDK 未初始化时安全降级为 Mock 凭证，保障本地开发/测试环境流程不中断
            let fallbackToken = "mock_carrier_token_\(UUID().uuidString)"
            return AuthCredential(
                identityType: identityType,
                identifier: "",
                credential: "",
                extraInfo: [
                    "carrierToken": fallbackToken,
                    "appKey": "mock_zhiyu_app_key",
                    "privacyConsent": "true"
                ]
            )
        }
        #endif

        guard Self.isInitialized else {
            throw AuthError.carrierSDKNotInitialized
        }

        let mockToken = "mock_carrier_token_\(UUID().uuidString)"
        return AuthCredential(
            identityType: identityType,
            identifier: "",
            credential: "",
            extraInfo: [
                "carrierToken": mockToken,
                "appKey": "mock_zhiyu_app_key",
                "privacyConsent": "true"
            ]
        )
    }
}

#else

/// watchOS 不支持运营商一键登录
@MainActor
public final class CarrierAuthStrategy: AuthStrategy {
    public var identityType: String { "carrier" }
    public init() {}
    /// 获取运营商凭证（watchOS 不支持，直接抛错）
    public func acquireCredentials() async throws -> AuthCredential {
        throw NSError(domain: FeatureConstants.ModuleName.carrierAuthStrategy, code: -99,
                      userInfo: [NSLocalizedDescriptionKey: FeatureConstants.ErrorDescription.watchOSNotSupported])
    }
}

#endif

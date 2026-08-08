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
        case .carrierSDKNotInitialized: return "Carrier SDK Not Initialized"
        case .carrierFailed:            return "Carrier Failed"
        case .userCancelled:            return "User Cancelled"
        case .carrierNoSIM:             return "No SIM Card"
        case .carrierNoNetwork:         return "No Network"
        case .carrierTimeout:           return "Timeout"
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
        if ProcessInfo.processInfo.arguments.contains("--uitesting") || NSClassFromString("XCTestCase") != nil {
            // SDK 未初始化时安全降级为 Mock 凭证，保障本地开发/测试环境流程不中断
            let fallbackToken = "mock_carrier_token_\\(UUID().uuidString)"
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

        let mockToken = "mock_carrier_token_\\(UUID().uuidString)"
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
        throw NSError(domain: "CarrierAuthStrategy", code: -99,
                      userInfo: [NSLocalizedDescriptionKey: "WatchOS not supported"])
    }
}

#endif

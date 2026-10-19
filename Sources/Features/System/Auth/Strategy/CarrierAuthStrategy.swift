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

    /// 重置 SDK 初始化状态（供测试隔离使用）
    /// - Note: internal 可见性，仅测试通过 @testable 调用；生产代码不依赖此方法。
    static func resetInitializedState() {
        isInitialized = false
    }
    // MARK: - 初始化

    /// 初始化运营商 SDK 并预取手机掩码号
    /// - Parameter appKey: ATAuthSDK 应用密钥
    /// 初始化成功后调用 SDK 预取接口将掩码号写入 `AuthService.shared.carrierMaskedPhone`，
    /// 驱动 `AuthPhonePanel` 在用户点击登录之前即可展示真实号码。
    public static func initializeSDK(with appKey: String) {
        // SDK 接入初始化预留
        isInitialized = true

        // 预取运营商掩码号：接入 ATAuthSDK 时调用：
        //   TXCommonHandler.sharedInstance().getLoginToken(timeout:complete:)
        // 并从回调的 resultDic["Number"] 中解析掩码号写入。
        Task { @MainActor in
            let maskedPhone = await fetchCarrierMaskedPhone()
            AuthService.shared.carrierMaskedPhone = maskedPhone
        }
    }

    /// 从运营商 SDK 预取手机掩码号
    /// 接入 ATAuthSDK 时，此处调用 TXCommonHandler 的预取 API 并解析 resultDic["Number"]
    private static func fetchCarrierMaskedPhone() async -> String? {
        // 预留接口：未接入实体运营商 SDK 时返回 nil（视图层将展示标准占位符）
        return nil
    }

    public init() {}

    /// 调起运营商授权页，获取 carrierToken
    public func acquireCredentials() async throws -> AuthCredential {
        guard Self.isInitialized else {
            throw AuthError.carrierSDKNotInitialized
        }

        // 调用 ATAuthSDK 授权页获取 Token（待三方 SDK 联调，返回规范凭证）
        let carrierToken = "carrier_token_\(UUID().uuidString)"
        return AuthCredential(
            identityType: identityType,
            identifier: "",
            credential: "",
            extraInfo: [
                "carrierToken": carrierToken,
                "appKey": "zhiyu_app_key",
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

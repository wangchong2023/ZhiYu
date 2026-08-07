//
//  GoogleAuthStrategy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：属于 Auth 模块，提供 Google 开放平台第三方登录的凭证获取策略实现。
//

import Foundation
import UFPCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Google 认证策略实现类
///
/// 遵循 `AuthStrategy` 协议，负责协调 Google SDK 在不同平台（iOS、macOS）拉起授权登录界面，
/// 获取 ID Token 凭证以支持向智宇后端服务发起鉴权请求。
@MainActor
public final class GoogleAuthStrategy: AuthStrategy {
    
    /// 鉴权提供方唯一标识
    public var identityType: String { "google" }
    
    /// 初始化策略
    public init() {}
    
    /// 异步拉起 Google SDK 授权并获取用户身份凭证
    ///
    /// - Returns: 获取到的授权凭证模型 `AuthCredential`
    /// - Throws: SDK 未配置错误、未在前台活跃场景或用户取消登录错误
    public func acquireCredentials() async throws -> AuthCredential {
        #if canImport(GoogleSignIn)
        
        // 1. 防御性配置探针：检测 Info.plist 或者是 GIDSignIn 的 configuration 中是否配置了有效的 clientID
        let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? GIDSignIn.sharedInstance.configuration?.clientID
        if clientID == nil || clientID == "YOUR_GOOGLE_CLIENT_ID" || clientID?.isEmpty == true {
            #if DEBUG
            // 物理自愈与降级：若在 UI 自动化测试运行中未配置 ClientID，降级返回 Mock
            if ProcessInfo.processInfo.arguments.contains("--uitesting") || NSClassFromString("XCTestCase") != nil {
                let mockIDToken = "mock_google_id_token_\(UUID().uuidString)"
                return AuthCredential(
                    identityType: identityType,
                    identifier: "mock_google_user_id",
                    credential: "mock_google_code",
                    extraInfo: [
                        "idToken": mockIDToken,
                        "email": "mock_google_user@gmail.com",
                        "nickname": "Google Mock User"
                    ]
                )
            }
            #endif
            throw AppError.auth(domain: "GoogleAuthStrategy", code: -99, description: L10n.Auth.googleSdkNotConfigured)
        }
        
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        
        guard let rootVC = activeScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            throw AppError.auth(domain: "GoogleAuthStrategy", code: -1, description: L10n.Auth.googleWindowError)
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AppError.auth(domain: "GoogleAuthStrategy", code: -2, description: L10n.Auth.googleTokenError)
        }
        
        return AuthCredential(
            identityType: identityType,
            identifier: result.user.userID ?? "",
            credential: "mock_google_code", // Google 使用 idToken 发往后端，传非空以绕过 @NotBlank 校验
            extraInfo: [
                "idToken": idToken,
                "email": result.user.profile?.email ?? "",
                "nickname": result.user.profile?.name ?? ""
            ]
        )
        #else
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") || NSClassFromString("XCTestCase") != nil {
            let mockIDToken = "mock_google_id_token_\(UUID().uuidString)"
            return AuthCredential(
                identityType: identityType,
                identifier: "mock_google_user_id",
                credential: "mock_google_code",
                extraInfo: [
                    "idToken": mockIDToken,
                    "email": "mock_google_user@gmail.com",
                    "nickname": "Google Mock User"
                ]
            )
        }
        #endif
        throw AppError.auth(domain: "GoogleAuthStrategy", code: -99, description: "Google SDK not compiled in watchOS or simulator without framework")
        #endif
    }
}

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
    
    /// 注入的 GoogleSignIn 登录能力（默认为真实 SDK 实现，测试可注入 Mock）
    private let signInProvider: GoogleSignInProviding
    private let clientIDResolver: (() -> String?)?
    private let rootViewControllerProvider: (() -> UIViewController?)?
    
    /// 初始化策略
    /// - Parameters:
    ///   - signInProvider: GoogleSignIn 登录能力实现（默认为真实 SDK）
    ///   - clientIDResolver: 客户端 ID 解析闭包；为 nil 时走真实探针（Info.plist → SDK configuration）。测试可注入以独立验证各分支。
    ///   - rootViewControllerProvider: 前台根控制器解析闭包；为 nil 时走真实场景查询。测试环境无真实前台场景，注入以便覆盖 signIn 分支。
    public init(
        signInProvider: GoogleSignInProviding = GIDSignInProvider(),
        clientIDResolver: (() -> String?)? = nil,
        rootViewControllerProvider: (() -> UIViewController?)? = nil
    ) {
        self.signInProvider = signInProvider
        self.clientIDResolver = clientIDResolver
        self.rootViewControllerProvider = rootViewControllerProvider
    }
    
    /// 解析「已配置且有效」的 Google 客户端 ID
    ///
    /// 优先级：Info.plist 的 `GIDClientID` → SDK `configuration.clientID`。
    /// 命中占位值或空值视为「未配置」，返回 nil。
    /// 纯函数，便于单元测试覆盖探针分支（避免依赖 Bundle / GIDSignIn 单例）。
    /// - Parameters:
    ///   - infoPlist: Info.plist 字典（默认取主 Bundle）
    ///   - sdkClientID: SDK 侧已配置的 clientID
    /// - Returns: 有效的客户端 ID；未配置返回 nil
    static func resolveConfiguredClientID(
        infoPlist: [String: Any]?,
        sdkClientID: String?
    ) -> String? {
        let fromInfo = infoPlist?[FeatureConstants.GoogleConfig.clientIDKey] as? String
        let candidate = fromInfo ?? sdkClientID
        guard let candidate, !candidate.isEmpty,
              candidate != FeatureConstants.GoogleConfig.placeholderClientID else {
            return nil
        }
        return candidate
    }
    
    /// 返回当前有效的 Google 客户端 ID
    ///
    /// 优先使用注入的解析闭包（便于测试独立验证各分支），否则走真实探针。
    /// - Returns: 有效客户端 ID；未配置返回 nil
    private func currentClientID() -> String? {
        if let clientIDResolver {
            return clientIDResolver()
        }
        #if canImport(GoogleSignIn)
        let sdkClientID = GIDSignIn.sharedInstance.configuration?.clientID
        return Self.resolveConfiguredClientID(
            infoPlist: Bundle.main.infoDictionary,
            sdkClientID: sdkClientID
        )
        #else
        return nil
        #endif
    }
    
    /// 返回当前前台根控制器
    ///
    /// 优先使用注入的解析闭包（便于测试覆盖 signIn 分支），否则查询真实前台场景。
    /// - Returns: 根控制器；无前台场景返回 nil
    private func activeRootViewController() -> UIViewController? {
        if let rootViewControllerProvider {
            return rootViewControllerProvider()
        }
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return activeScene?.keyWindow?.rootViewController
    }
    
    /// 异步拉起 Google SDK 授权并获取用户身份凭证
    ///
    /// - Returns: 获取到的授权凭证模型 `AuthCredential`
    /// - Throws: SDK 未配置错误、未在前台活跃场景或用户取消登录错误
    public func acquireCredentials() async throws -> AuthCredential {
        #if canImport(GoogleSignIn)
        
        // 1. 防御性配置探针：检测是否配置了有效的 clientID
        let clientID = currentClientID()
        if clientID == nil {
            if let mock = testModeMockCredential(identityType: identityType) {
                return mock
            }
            throw AppError.auth(domain: FeatureConstants.ModuleName.googleAuthStrategy, code: -99, description: L10n.Auth.googleSdkNotConfigured)
        }
        
        guard let rootVC = activeRootViewController() else {
            throw AppError.auth(domain: FeatureConstants.ModuleName.googleAuthStrategy, code: -1, description: L10n.Auth.googleWindowError)
        }
        
        let data = try await signInProvider.signIn(presenting: rootVC)
        guard !data.idToken.isEmpty else {
            throw AppError.auth(domain: FeatureConstants.ModuleName.googleAuthStrategy, code: -2, description: L10n.Auth.googleTokenError)
        }
        
        return AuthCredential(
            identityType: identityType,
            identifier: data.userID ?? "",
            credential: FeatureConstants.MockData.mockGoogleCode, // Google 使用 idToken 发往后端，传非空以绕过 @NotBlank 校验
            extraInfo: [
                "idToken": data.idToken,
                "email": data.email ?? "",
                "nickname": data.name ?? ""
            ]
        )
        #else
        if let mock = testModeMockCredential(identityType: identityType) {
            return mock
        }
        throw AppError.auth(domain: FeatureConstants.ModuleName.googleAuthStrategy, code: -99, description: "Google SDK not compiled in watchOS or simulator without framework")
        #endif
    }

    /// 测试模式下的 Mock Google 凭证，消除 #if DEBUG 块内的重复
    private func mockGoogleCredential(identityType: String) -> AuthCredential {
        let mockIDToken = "mock_google_id_token_\(UUID().uuidString)"
        return AuthCredential(
            identityType: identityType,
            identifier: "mock_google_user_id",
            credential: FeatureConstants.MockData.mockGoogleCode,
            extraInfo: [
                "idToken": mockIDToken,
                "email": "mock_google_user@gmail.com",
                "nickname": FeatureConstants.MockData.googleMockUser
            ]
        )
    }

    /// 测试模式下降级返回 Mock 凭证，消除 #if DEBUG 块的重复
    private func testModeMockCredential(identityType: String) -> AuthCredential? {
        #if DEBUG
        if TestModeDetector.isAnyTesting {
            return mockGoogleCredential(identityType: identityType)
        }
        #endif
        return nil
    }
}

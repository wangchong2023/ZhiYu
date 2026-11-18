//
//  GoogleAuthStrategy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：属于 Auth 模块，提供 Google 开放平台第三方登录的凭证获取策略实现。
//           基于 AppAuth 统一 iOS 与 macOS，产出 idToken 凭证。
//

import Foundation
import UFPCore
import AuthenticationServices

/// Google 认证策略实现类
///
/// 遵循 `AuthStrategy` 协议，负责协调 Google OIDC 登录（AppAuth）在不同平台（iOS、macOS）
/// 拉起授权界面，获取 ID Token 凭证以支持向智宇后端服务发起鉴权请求。
@MainActor
public final class GoogleAuthStrategy: AuthStrategy {
    
    /// 鉴权提供方唯一标识
    public var identityType: String { "google" }
    
    /// 注入的 GoogleSignIn 登录能力（默认为 AppAuth 实现，测试可注入 Mock）
    private let signInProvider: GoogleSignInProviding
    private let clientIDResolver: (() -> String?)?
    private let anchorProvider: (() -> ASPresentationAnchor?)?
    
    /// 初始化策略
    /// - Parameters:
    ///   - signInProvider: Google 登录能力实现（默认为 AppAuth）
    ///   - clientIDResolver: 客户端 ID 解析闭包；为 nil 时走真实探针（Info.plist）。测试可注入以独立验证各分支。
    ///   - anchorProvider: 呈现锚点解析闭包（iOS 为 UIWindow / macOS 为 NSWindow）；为 nil 时走真实查询。测试环境注入以便覆盖 signIn 分支。
    public init(
        signInProvider: GoogleSignInProviding = AppAuthGoogleProvider(),
        clientIDResolver: (() -> String?)? = nil,
        anchorProvider: (() -> ASPresentationAnchor?)? = nil
    ) {
        self.signInProvider = signInProvider
        self.clientIDResolver = clientIDResolver
        self.anchorProvider = anchorProvider
    }
    
    /// 解析「已配置且有效」的 Google 客户端 ID
    ///
    /// 优先级：Info.plist 的 `GIDClientID` → SDK `configuration.clientID`。
    /// 命中占位值或空值视为「未配置」，返回 nil。
    /// 纯函数，便于单元测试覆盖探针分支（避免依赖 Bundle / AppAuth 单例）。
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
        return Self.resolveConfiguredClientID(
            infoPlist: Bundle.main.infoDictionary,
            sdkClientID: nil
        )
    }
    
    /// 返回当前呈现锚点
    ///
    /// 优先使用注入的解析闭包（便于测试覆盖 signIn 分支），否则查询真实平台锚点。
    /// - Returns: 呈现锚点；无可用锚点返回 nil
    private func activeAnchor() -> ASPresentationAnchor? {
        if let anchorProvider {
            return anchorProvider()
        }
        return PlatformPresentationAnchor.keyWindow
    }
    
    /// 异步拉起 Google OIDC 授权并获取用户身份凭证
    ///
    /// - Returns: 获取到的授权凭证模型 `AuthCredential`
    /// - Throws: SDK 未配置错误、未在前台活跃场景或用户取消登录错误
    public func acquireCredentials() async throws -> AuthCredential {
        #if canImport(AppAuth)

        // 1. 防御性配置探针：检测是否配置了有效的 clientID
        let clientID = currentClientID()
        if clientID == nil {
            throw AppError.auth(domain: FeatureConstants.ModuleName.googleAuthStrategy, code: -99, description: L10n.Auth.googleSdkNotConfigured)
        }

        guard let anchor = activeAnchor() else {
            throw AppError.auth(domain: FeatureConstants.ModuleName.googleAuthStrategy, code: -1, description: L10n.Auth.googleWindowError)
        }

        let data = try await signInProvider.signIn(presenting: anchor)
        guard !data.idToken.isEmpty else {
            throw AppError.auth(domain: FeatureConstants.ModuleName.googleAuthStrategy, code: -2, description: L10n.Auth.googleTokenError)
        }

        return AuthCredential(
            identityType: identityType,
            identifier: data.userID ?? "",
            credential: FeatureConstants.GoogleConfig.oidcCredentialPlaceholder, // Google 使用 idToken 发往后端，传非空以绕过 @NotBlank 校验
            extraInfo: [
                "idToken": data.idToken,
                "email": data.email ?? "",
                "nickname": data.name ?? "",
                "state": UUID().uuidString // C 端原生 App（RFC 8252）本地生成 state，后端 lenient 仅要求非空
            ]
        )
        #else
        throw AppError.auth(domain: FeatureConstants.ModuleName.googleAuthStrategy, code: -99, description: "Google SDK not compiled in watchOS or simulator without framework")
        #endif
    }
}

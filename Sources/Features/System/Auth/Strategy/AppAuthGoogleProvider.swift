//
//  AppAuthGoogleProvider.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：基于 AppAuth（OIDAuthorizationService + PKCE）实现 Google OIDC 登录，
//           统一 iOS 与 macOS 平台，产出与 GIDSignIn 一致的 idToken 凭证。
//

import Foundation
import UFPCore
import AppAuth
import AuthenticationServices

/// 基于 AppAuth 的 Google OIDC 登录提供方（iOS / macOS 统一实现）
///
/// 通过 `OIDAuthState.authState(byPresenting:)` 拉起授权，AppAuth 自动完成
/// state/nonce/PKCE(S256) 生成与 authorization code → idToken 交换，
/// 产出的 `GoogleSignInCredentialData.idToken` 与旧 GIDSignIn 输出一致，
/// 可直接透传后端 `/api/v1/auth/oauth` 验签。
@MainActor
public struct AppAuthGoogleProvider: GoogleSignInProviding {

    /// 注入的 clientID 解析闭包（nil 时从 Info.plist 读取 GIDClientID 键）
    private let clientIDResolver: (() -> String?)?

    public init(clientIDResolver: (() -> String?)? = nil) {
        self.clientIDResolver = clientIDResolver
    }

    public func signIn(presenting anchor: ASPresentationAnchor) async throws -> GoogleSignInCredentialData {
        // 1. 防御性配置探针：解析有效 clientID（占位/空视为未配置）
        let clientID = clientIDResolver?() ?? Self.defaultClientID()
        guard let clientID,
              !clientID.isEmpty,
              clientID != FeatureConstants.GoogleConfig.placeholderClientID else {
            throw AppError.auth(
                domain: FeatureConstants.ModuleName.googleAuthStrategy,
                code: -99,
                description: L10n.Auth.googleSdkNotConfigured
            )
        }

        // 2. 构造 OIDC 配置与授权请求（opinionated init 自动生成 state/nonce/PKCE）
        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: Self.url(FeatureConstants.GoogleConfig.authorizationEndpoint),
            tokenEndpoint: Self.url(FeatureConstants.GoogleConfig.tokenEndpoint)
        )
        let redirectURIString = FeatureConstants.GoogleConfig.redirectSchemePrefix
            + clientID
            + FeatureConstants.GoogleConfig.redirectPathSuffix
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: clientID,
            clientSecret: nil,
            scopes: FeatureConstants.GoogleConfig.oidcScopes,
            redirectURL: Self.url(redirectURIString),
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )

        // 3. 拉起授权并交换 idToken（平台差异：iOS 用 UIViewController，macOS 用 NSWindow）
        let result = try await performAuthorization(request: request, anchor: anchor)
        guard !result.idToken.isEmpty else {
            throw AppError.auth(
                domain: FeatureConstants.ModuleName.googleAuthStrategy,
                code: -2,
                description: L10n.Auth.googleTokenError
            )
        }

        return GoogleSignInCredentialData(
            idToken: result.idToken,
            userID: result.userID,
            email: nil,
            name: nil
        )
    }

    /// 跨平台拉起授权：iOS 从 UIWindow 取根控制器，macOS 直接用 NSWindow
    private func performAuthorization(
        request: OIDAuthorizationRequest,
        anchor: ASPresentationAnchor
    ) async throws -> (idToken: String, userID: String?) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(idToken: String, userID: String?), Error>) in
            // 强持有会话直至回调触发，避免授权流程因提前释放而中断
            var session: (any OIDExternalUserAgentSession)?
            let finish: (OIDAuthState?, Error?) -> Void = { authState, error in
                if let authState, let idToken = authState.lastTokenResponse?.idToken {
                    let userID = authState.lastTokenResponse?.additionalParameters?["sub"] as? String
                    continuation.resume(returning: (idToken, userID))
                } else {
                    continuation.resume(throwing: error ?? AppError.auth(
                        domain: FeatureConstants.ModuleName.googleAuthStrategy,
                        code: -1,
                        description: L10n.Auth.googleWindowError
                    ))
                }
                session?.cancel()
            }
            #if canImport(UIKit) && !os(watchOS)
            // ASPresentationAnchor 在 iOS/Catalyst 下即 UIWindow
            guard let rootVC = anchor.rootViewController else {
                continuation.resume(throwing: AppError.auth(
                    domain: FeatureConstants.ModuleName.googleAuthStrategy,
                    code: -1,
                    description: L10n.Auth.googleWindowError
                ))
                return
            }
            session = OIDAuthState.authState(
                byPresenting: request,
                presenting: rootVC,
                callback: finish
            )
            #elseif canImport(AppKit)
            // ASPresentationAnchor 在 macOS 下即 NSWindow
            guard let window = anchor as? NSWindow else {
                continuation.resume(throwing: AppError.auth(
                    domain: FeatureConstants.ModuleName.googleAuthStrategy,
                    code: -1,
                    description: L10n.Auth.googleWindowError
                ))
                return
            }
            session = OIDAuthState.authState(
                byPresenting: request,
                presenting: window,
                callback: finish
            )
            #endif
        }
    }

    /// 从 Info.plist 读取默认 clientID
    private static func defaultClientID() -> String? {
        Bundle.main.infoDictionary?[FeatureConstants.GoogleConfig.clientIDKey] as? String
    }

    /// 从字面量构造 URL（配置常量来自 FeatureConstants，非外部输入）
    private static func url(_ literal: String) -> URL {
        guard let url = URL(string: literal) else {
            preconditionFailure("AppAuthGoogleProvider: 无效 URL 常量 \(literal)")
        }
        return url
    }
}

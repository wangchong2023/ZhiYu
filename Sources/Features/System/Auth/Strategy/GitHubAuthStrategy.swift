//
//  GitHubAuthStrategy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：实现 GitHub OAuth 认证策略。
//

import Foundation
import UFPCore
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif

/// GitHub 认证策略实现类
@MainActor
public final class GitHubAuthStrategy: NSObject, AuthStrategy {
    
    public var identityType: String { "github" }
    
    // MARK: - 配置
    // 从 AppConfig.json 读取 GitHub OAuth Client ID
    private let clientId = AppConfig.gitHubOAuthClientId
    private let callbackScheme = "zhiyu" // 需与 URL Types 保持一致
    
    public override init() {}
    
    /// acquireCredentials
    /// - Returns: 返回值
    public func acquireCredentials() async throws -> AuthCredential {
        return try await withCheckedThrowingContinuation { continuation in
            let state = UUID().uuidString
            
            // 1. 防御性检查：验证 clientId 是否被正确配置，若在 UI 自动化测试且 DEBUG 下，降级返回 Mock 凭证，避免弹出错误网页
            if clientId.isEmpty {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--uitesting") || NSClassFromString("XCTestCase") != nil {
                    let mockCode = "mock_github_code_\(UUID().uuidString)"
                    let cred = AuthCredential(
                        identityType: identityType,
                        identifier: "mock_github_user_id",
                        credential: mockCode,
                        extraInfo: ["state": state, "nickname": "GitHub Mock User"]
                    )
                    continuation.resume(returning: cred)
                    return
                }
                #endif
                continuation.resume(throwing: AppError.auth(domain: "GitHubAuthStrategy", code: -99, description: L10n.Auth.authFailed))
                return
            }
            
            let urlString = "\(AppConstants.URLs.gitHubOAuthAuthorize)?client_id=\(clientId)&state=\(state)&scope=read:user,user:email"
            guard let url = URL(string: urlString) else {
                continuation.resume(throwing: AppError.auth(domain: "GitHubAuthStrategy", code: -1, description: "GitHub URL Error"))
                return
            }
            
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true),
                      let queryItems = components.queryItems,
                      let code = queryItems.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AppError.auth(domain: "GitHubAuthStrategy", code: -2, description: "GitHub Callback Error"))
                    return
                }
                
                let cred = AuthCredential(
                    identityType: "github",
                    identifier: "", 
                    credential: code,
                    extraInfo: ["state": state]
                )
                continuation.resume(returning: cred)
            }
            
            #if canImport(UIKit)
            session.presentationContextProvider = self
            #endif
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }
}

#if canImport(UIKit)
extension GitHubAuthStrategy: ASWebAuthenticationPresentationContextProviding {

    /// presentationAnchor
    /// - Returns: 返回值
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        
        return activeScene?.windows.first { $0.isKeyWindow } ?? UIWindow()
    }
}
#endif

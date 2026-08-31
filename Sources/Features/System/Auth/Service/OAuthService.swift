//
//  OAuthService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：OAuth 多渠道统一登录流程 — Apple / 微信 / Google / GitHub / 运营商一键免密。
//

import Foundation
import UFPCore

extension AuthService {

    // MARK: - 多渠道中台统一登录

    /// 使用指定策略进行第三方登录
    /// - Parameter strategy: OAuth / 一键登录策略实例
    /// - Returns: 是否登录成功
    @MainActor
    public func login(using strategy: any AuthStrategy) async -> Bool {
        do {
            #if DEBUG
            if isMockBackend {
                // 在 Mock 模式下，直接构造测试凭证，跳过底层 SDK (如 FaceID) 唤起，防止 UI 测试阻塞
                let mockCred = AuthCredential(identityType: strategy.identityType, identifier: FeatureConstants.MockData.mockSub123, credential: FeatureConstants.MockCredential.mockJwtToken, extraInfo: [FeatureConstants.MockCredentialKey.nickname: FeatureConstants.MockData.mockAutologinUser])
                return try await sendAuthRequestToBackend(mockCred)
            }
            #endif

            // 1. 驱动客户端 SDK 获取凭证
            let credential = try await strategy.acquireCredentials()

            // 2. 发送至后端校验
            return try await sendAuthRequestToBackend(credential)
        } catch {
            Logger.shared.error("[AuthService] OAuth login failed", error: error)
            return false
        }
    }

    /// 将第三方凭证发送至后端完成校验与 JWT 签发
    /// - Parameter cred: 客户端获取的身份凭证
    /// - Returns: 是否登录成功
    internal func sendAuthRequestToBackend(_ cred: AuthCredential) async throws -> Bool {
        #if DEBUG
        if let result = await tryMockAuthRequest(cred) { return result }
        #endif

        let info = resolveAuthRequestInfo(cred)
        let response = try await sendOAuthRequest(path: info.path, reqBody: info.body)
        let name = cred.extraInfo?["nickname"] ?? "ZhiYu User"
        return await handleSuccessfulLogin(response: response, identity: name)
    }

    #if DEBUG
    /// Mock 模式下构造假登录响应
    private func tryMockAuthRequest(_ cred: AuthCredential) async -> Bool? {
        guard isMockBackend else { return nil }
        let name = cred.extraInfo?["nickname"] ?? "ZhiYu User"
        let response = LoginResponse(
            accessToken: "mock_jwt_access_token_\(UUID().uuidString)",
            refreshToken: "mock_jwt_refresh_token_\(UUID().uuidString)",
            expiresIn: 3600,
            tokenType: FeatureConstants.MockData.bearer,
            isNewUser: false,
            totpRequired: false
        )
        return await handleSuccessfulLogin(response: response, identity: name)
    }
    #endif

    // MARK: - 私有路由解析

    private struct AuthRequestInfo {
        let path: String
        let body: Any
    }

    /// 根据身份凭证解析后端 API 请求路径与请求体
    /// - Parameter cred: 客户端获取的 OAuth/一键登录身份凭证
    /// - Returns: 包含请求路径及请求体数据的结构体
    private func resolveAuthRequestInfo(_ cred: AuthCredential) -> AuthRequestInfo {
        switch cred.identityType {
        // 苹果登录
        case FeatureConstants.OAuthProvider.apple: return AuthRequestInfo(path: APIPaths.oauthApplePath, body: OAuthAppleRequest(code: cred.credential, state: cred.extraInfo?["state"], idToken: cred.extraInfo?["idToken"]))
        // 微信登录
        case FeatureConstants.OAuthProvider.wechat: return AuthRequestInfo(path: APIPaths.oauthWeChatPath, body: OAuthWeChatRequest(code: cred.credential, state: cred.extraInfo?["state"]))
        // 谷歌登录
        case FeatureConstants.OAuthProvider.google: return AuthRequestInfo(path: APIPaths.oauthGooglePath, body: OAuthGoogleRequest(code: cred.credential, idToken: cred.extraInfo?["idToken"] ?? ""))
        // GitHub 登录
        case FeatureConstants.OAuthProvider.github: return AuthRequestInfo(path: APIPaths.oauthGitHubPath, body: OAuthGitHubRequest(code: cred.credential, state: cred.extraInfo?["state"]))
        // 运营商一键免密登录
        case FeatureConstants.OAuthProvider.carrier: return AuthRequestInfo(path: APIPaths.carrierAuthPath, body: CarrierAuthRequest(carrierToken: cred.extraInfo?["carrierToken"] ?? "", appKey: cred.extraInfo?["appKey"] ?? "", privacyConsent: cred.extraInfo?["privacyConsent"] == SystemConstants.BooleanLiteral.true))
        default:
            Logger.shared.error("未支持的登录渠道类型: \(cred.identityType)")
            return AuthRequestInfo(path: "", body: "")
        }
    }

    /// 根据请求体类型将 OAuth 请求发送至对应后端端点
    /// - Parameters:
    ///   - path: API 路径
    ///   - reqBody: 请求体（需为已知 OAuth 请求类型）
    /// - Returns: 登录响应
    private func sendOAuthRequest(path: String, reqBody: Any) async throws -> LoginResponse {
        if let appleReq = reqBody as? OAuthAppleRequest {
            return try await NetworkClient.shared.request(path: path, method: SystemConstants.HTTPMethod.post, body: appleReq, requiresAuth: false)
        }
        if let wechatReq = reqBody as? OAuthWeChatRequest {
            return try await NetworkClient.shared.request(path: path, method: SystemConstants.HTTPMethod.post, body: wechatReq, requiresAuth: false)
        }
        if let googleReq = reqBody as? OAuthGoogleRequest {
            return try await NetworkClient.shared.request(path: path, method: SystemConstants.HTTPMethod.post, body: googleReq, requiresAuth: false)
        }
        if let githubReq = reqBody as? OAuthGitHubRequest {
            return try await NetworkClient.shared.request(path: path, method: SystemConstants.HTTPMethod.post, body: githubReq, requiresAuth: false)
        }
        if let carrierReq = reqBody as? CarrierAuthRequest {
            return try await NetworkClient.shared.request(path: path, method: SystemConstants.HTTPMethod.post, body: carrierReq, requiresAuth: false)
        }
        throw NetworkError.unexpected("Unsupported auth request type")
    }
}

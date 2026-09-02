//
//  AppleAuthStrategy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：依托 Apple 原生 AuthenticationServices 框架，物理拉起系统级 FaceID/TouchID 进行 Apple 登录，并收集凭证。
//

import Foundation
import UFPCore
import AuthenticationServices

/// Apple 认证错误域与错误码常量
private enum AppleAuthErrorSpec {
    static let domain = "AppleAuthStrategy"
    static let tokenExtractFailedCode = -1
}

/// Apple ID 认证策略实现类
/// 负责在 iOS 设备上启动原生 Apple 授权对话框，并将结果转换为统一的 AuthCredential 模型。
@MainActor
public final class AppleAuthStrategy: NSObject, AuthStrategy {
    
    // MARK: - 协议属性
    
    /// 统一认证的渠道标识
    public var identityType: String { "apple" }
    
    // MARK: - 内部凭证延续机制
    
    /// 利用 CheckedContinuation 桥接 XCTest/AuthenticationServices 的 Delegate 异步回调与 Swift 协程
    private var continuation: CheckedContinuation<AuthCredential, Error>?
    
    // MARK: - 核心操作方法
    
    /// 物理调起 Apple 原生登录控制器，启动 FaceID/TouchID 鉴权流程
    /// - Returns: 标准化登录凭证
    /// - Throws: 用户取消授权、获取令牌失败等 NSError
    public func acquireCredentials() async throws -> AuthCredential {
        #if DEBUG
        #if targetEnvironment(simulator)
        // 物理自愈与降级：若在模拟器进行 UI 自动化测试时，为避免拉起 ASAuthorizationController 物理弹窗失败超时，降级返回 Mock
        // 只有显式在启动参数中配置了 --uitesting 时才退避进入 mock，日常手动调试及真机均走真实逻辑
        if TestModeDetector.isAnyTesting {
            let mockAppleToken = "mock_apple_identity_token_\(UUID().uuidString)"
            return AuthCredential(
                identityType: identityType,
                identifier: "mock_apple_user_id",
                credential: FeatureConstants.MockData.mockAppleCode,
                extraInfo: [
                    "idToken": mockAppleToken,
                    "email": "mock_apple_user@example.com",
                    "nickname": "Apple Mock User"
                ]
            )
        }
        #endif
        #endif

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            #if canImport(UIKit)
            controller.presentationContextProvider = self
            #endif
            controller.performRequests()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthStrategy: ASAuthorizationControllerDelegate {
    
    /// 授权成功回调，解析原始 Apple ID 凭证并转换
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let tokenString = String(data: tokenData, encoding: .utf8) else {
            let error = AppError.auth(domain: AppleAuthErrorSpec.domain, code: AppleAuthErrorSpec.tokenExtractFailedCode, description: L10n.Auth.appleTokenExtractFailed)
            continuation?.resume(throwing: error)
            return
        }
        
        // sub (Subject ID) 是 Apple 用户在当前 App Group 下的全局唯一用户指纹
        let sub = credential.user 
        
        // 提取用户的姓名信息并转化为昵称
        var extra: [String: String] = [:]
        if let name = credential.fullName {
            let nickname = [name.givenName, name.familyName].compactMap { $0 }.joined(separator: " ")
            if !nickname.isEmpty {
                extra["nickname"] = nickname
            }
        }
        
        let authCred = AuthCredential(
            identityType: identityType,
            identifier: sub,
            credential: tokenString,
            extraInfo: extra
        )
        continuation?.resume(returning: authCred)
    }
    
    /// 授权失败或用户主动取消回调
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
    }
}

#if canImport(UIKit)
// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleAuthStrategy: ASAuthorizationControllerPresentationContextProviding {
    
    /// 获取当前拉起 FaceID 物理弹窗的安全锚点 Window 实例
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        PlatformPresentationAnchor.keyWindow
    }
}
#endif

//
//  GoogleSignInProviding.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/10/17.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：抽象 GoogleSignIn SDK 的登录能力，解耦 GIDSignIn 全局单例以便单元测试注入 Mock。
//

import Foundation
import UIKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// GoogleSignIn SDK 未编译时的错误描述（技术性说明，非用户可见文案，不走 L10n）
private enum GoogleSdkErrorText {
    static let notCompiled = "Google SDK not compiled"
}

/// Google Sign-In 登录返回的用户凭证数据（解耦 SDK 具体类型，便于注入测试）
public struct GoogleSignInCredentialData {
    public let idToken: String
    public let userID: String?
    public let email: String?
    public let name: String?

    public init(idToken: String, userID: String?, email: String?, name: String?) {
        self.idToken = idToken
        self.userID = userID
        self.email = email
        self.name = name
    }
}

/// Google Sign-In 登录能力抽象，测试中可注入 Mock 实现
@MainActor
public protocol GoogleSignInProviding {
    func signIn(presenting: UIViewController) async throws -> GoogleSignInCredentialData
}

/// 默认实现：包装 GoogleSignIn SDK 的单例登录并提取用户凭证
@MainActor
public struct GIDSignInProvider: GoogleSignInProviding {

    public init() {}

    public func signIn(presenting: UIViewController) async throws -> GoogleSignInCredentialData {
        #if canImport(GoogleSignIn)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        return GoogleSignInCredentialData(
            idToken: result.user.idToken?.tokenString ?? "",
            userID: result.user.userID,
            email: result.user.profile?.email,
            name: result.user.profile?.name
        )
        #else
        throw AppError.auth(
            domain: FeatureConstants.ModuleName.googleAuthStrategy,
            code: -99,
            description: GoogleSdkErrorText.notCompiled
        )
        #endif
    }
}

//
//  GoogleSignInProviding.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/10/17.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：抽象 Google OIDC 登录能力，解耦 AppAuth SDK 依赖以便单元测试注入 Mock。
//

import Foundation
import AuthenticationServices

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
/// - Parameter anchor: 跨平台呈现锚点（iOS 为 UIWindow，macOS 为 NSWindow）
@MainActor
public protocol GoogleSignInProviding {
    func signIn(presenting anchor: ASPresentationAnchor) async throws -> GoogleSignInCredentialData
}

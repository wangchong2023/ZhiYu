//
//  SelfSignedSessionDelegateProvider.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/10/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：信任自签名证书的 URLSessionDelegate 提供者。
//  是否启用由 AppConfig.allowSelfSignedCert 运行时开关控制（本地开发/联调），
//  生产 AppConfig.json 中必须为 false，避免信任不可信证书。
//

import Foundation
import UFPCore

/// 自签名证书信任代理
public final class SelfSignedSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

/// 自签名证书信任策略提供者
public struct SelfSignedSessionDelegateProvider: URLSessionDelegateProvider {
    public init() {}

    public func makeSessionDelegate() -> URLSessionDelegate? {
        SelfSignedSessionDelegate()
    }
}

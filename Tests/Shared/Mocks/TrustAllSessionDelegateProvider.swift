//
//  TrustAllSessionDelegateProvider.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Test] 单元测试共享基础设施
//  核心职责：用于测试或本地自签名证书调试环境的 URLSessionDelegate 提供者实现。
//

import Foundation
import UFPCore

/// 自签名证书信任代理
public final class TrustAllSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
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
public struct TrustAllSessionDelegateProvider: URLSessionDelegateProvider {
    public init() {}

    public func makeSessionDelegate() -> URLSessionDelegate? {
        TrustAllSessionDelegate()
    }
}

//
//  ApplePlatformCapabilities.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：Apple 全平台通用能力提供者（生物识别、CoreML模型编译等）。
//

import Foundation
import LocalAuthentication
import CoreML

#if canImport(LocalAuthentication)
/// Apple 平台通用生物识别提供者 (iOS / macOS / iPadOS) (DRY)
@MainActor
public struct AppleBiometricAuthProvider: BiometricAuthProviderProtocol {
    public var authenticationPolicy: LAPolicy { .deviceOwnerAuthenticationWithBiometrics }

    public init() {}

    public func canEvaluatePolicy(context: LAContext) -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(authenticationPolicy, error: &error)
    }

    public func evaluatePolicy(context: LAContext, reason: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(authenticationPolicy, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
#endif

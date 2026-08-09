//
//  WatchPlatformCapabilities.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：watchOS 平台实现：语音听写、健康数据同步、紧凑 UI。
//
import Foundation
import LocalAuthentication

/// watchOS 平台错误域与错误码常量
private enum WatchPlatformErrorSpec {
    static let modelCompilerDomain = "WatchModelCompiler"
    static let noModelCode = -1
    static let noModelDescription = "watchOS_NoModel"
}

// MARK: - 生物识别

/// watchOS 平台的鉴权提供者（使用设备密码）
@MainActor
struct WatchBiometricAuthProvider: BiometricAuthProviderProtocol {
    var authenticationPolicy: LAPolicy { .deviceOwnerAuthentication }
    
    /// can评估Policy
    /// - Parameter context: context
    /// - Returns: 是否成功
    func canEvaluatePolicy(context: LAContext) -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(authenticationPolicy, error: &error)
    }
    
    /// 评估Policy
    /// - Parameter context: context
    /// - Parameter reason: reason
    /// - Returns: 是否成功
    func evaluatePolicy(context: LAContext, reason: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(authenticationPolicy, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}

// MARK: - 模型编译

/// watchOS 不支持运行时模型编译，作为 Stub 处理
struct WatchModelCompiler: MLModelCompilerProtocol {
    var supportsCompilation: Bool { false }
    
    /// 编译Model
    /// - Returns: 链接
    func compileModel(at url: URL) async throws -> URL {
        throw NSError(domain: WatchPlatformErrorSpec.modelCompilerDomain, code: WatchPlatformErrorSpec.noModelCode, userInfo: [NSLocalizedDescriptionKey: WatchPlatformErrorSpec.noModelDescription])
    }
}

// MARK: - 安全存储

/// watchOS 无需或不支持书签持久化
struct WatchSecurityScopedStorage: SecurityScopedStorageProtocol {

    /// 存储添加书签
    func storeBookmark(for url: URL) {}

    /// 恢复URL
    /// - Returns: 可选值
    func restoreURL(from data: Data) -> URL? { nil }
}

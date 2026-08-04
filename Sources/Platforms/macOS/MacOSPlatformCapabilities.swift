//
//  MacOSPlatformCapabilities.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：macOS 平台实现：菜单栏、文件归档、辅助功能。
//
import Foundation
import UFPCore
import LocalAuthentication

// MARK: - 生物识别

/// macOS 平台的生物识别提供者
@MainActor
struct MacOSBiometricAuthProvider: BiometricAuthProviderProtocol {
    var authenticationPolicy: LAPolicy { .deviceOwnerAuthenticationWithBiometrics }
    
    /// 检查当前系统是否支持指定的生物识别安全策略。
    /// - Parameter context: 用于验证的本地安全上下文。
    /// - Returns: 如果设备支持并配置了该验证策略，则返回 true，否则返回 false。
    func canEvaluatePolicy(context: LAContext) -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(authenticationPolicy, error: &error)
    }
    
    /// 异步执行生物识别策略，验证设备所有者身份。
    /// - Parameters:
    ///   - context: 验证的本地安全上下文。
    ///   - reason: 呈献给用户的安全验证理由文案。
    ///   - Returns: 验证成功返回 true，失败或被用户取消返回 false。
    func evaluatePolicy(context: LAContext, reason: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(authenticationPolicy, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}

// MARK: - 安全存储

#if os(macOS)
/// macOS 安全存储：实现真正的 Security-Scoped Bookmarks 持久化
struct MacOSSecurityScopedStorage: SecurityScopedStorageProtocol {
    /// 为指定安全路径（如外部笔记本目录）创建并持久化安全作用域书签数据。
    /// - Parameter url: 待存储的物理路径 URL。
    func storeBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
            keyStore?.set(data, forKey: AppConstants.Keys.Storage.vaultBookmarkPrefix + url.lastPathComponent)
        } catch {
            Logger.shared.error("macOS_Error1: Failed to store bookmark for \(url.lastPathComponent)", error: error)
        }
    }
    
    /// 解析持久化的书签数据，恢复具有安全访问权限的沙盒 URL。
    /// - Parameter data: 被存储的二进制书签数据。
    /// - Returns: 恢复出的安全沙盒 URL。若数据损坏或失效则返回 nil。
    func restoreURL(from data: Data) -> URL? {
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale { return nil }
            return url
        } catch {
            Logger.shared.error("macOS_Error2: Failed to resolve bookmark data", error: error)
            return nil
        }
    }
}
#endif

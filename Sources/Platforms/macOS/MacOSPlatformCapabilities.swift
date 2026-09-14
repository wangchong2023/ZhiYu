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
import Dependencies
import LocalAuthentication

// MARK: - 生物识别

/// macOS 平台的生物识别提供者：复用 Apple 全平台通用实现（DRY）。
/// 详见 `ApplePlatformCapabilities.swift` 中的 `AppleBiometricAuthProvider`。
@MainActor
typealias MacOSBiometricAuthProvider = AppleBiometricAuthProvider

// MARK: - 安全存储

#if os(macOS)
/// macOS 安全存储：实现真正的 Security-Scoped Bookmarks 持久化
struct MacOSSecurityScopedStorage: SecurityScopedStorageProtocol {
    @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?
    /// 为指定安全路径（如外部笔记本目录）创建并持久化安全作用域书签数据。
    /// - Parameter url: 待存储的物理路径 URL。
    func storeBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
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

//
//  KeychainService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：实现 Keychain 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
import Security

/// 钥匙串服务包装器 (@SR-03: 安全存储鉴权令牌)
/// 提供对系统 Keychain 的轻量级访问，支持敏感数据的持久化存储与隔离。
class KeychainService: @unchecked Sendable {
    /// 真实单例（内部持有）
    private static let _shared = KeychainService()
    /// 测试覆盖：设置非 nil 值后 shared 返回 Mock 实例；在 tearDown 中置 nil 恢复
    nonisolated(unsafe) static var testOverride: KeychainService?
    /// 全局单例入口：测试模式下可被替换
    static var shared: KeychainService { testOverride ?? _shared }
    /// Keychain 服务标识符
    private let serviceName = "com.zhiyu.keychain"

    /// 键值存储抽象，用于 Keychain entitlements 缺失时的 DEBUG 降级回退。
    /// 使用 resolveOptional 优雅降级：DI 容器未就绪时返回 nil，避免启动/测试崩溃。
    @Inject private var keyStore: (any KeyStoreProtocol)?

    init() {}

    /// 存储敏感数据
    /// - Parameters:
    ///   - key: 键名
    ///   - value: 要存储的字符串
    func store(key: String, value: String) throws {
        Logger.shared.debug("[KeychainService] store() called for key: \(key)")
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        // 先删除旧项
        try? delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // VULN-012 修复：改用 WhenUnlockedThisDeviceOnly，禁止 iCloud/itunes 备份提取
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            if status == errSecMissingEntitlement {
                #if DEBUG && !os(watchOS)
                runOnMainSync { keyStore?.set(value, forKey: key) }
                return
                #endif
            }
            Logger.shared.error(" [KeychainService]  (\(key)): \(status)")
            throw KeychainError.storeFailed(status)
        }
    }

    /// 获取敏感数据
    /// - Parameter key: 键名
    /// - Returns: 存储的字符串，不存在则返回 nil
    func retrieve(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.unexpectedData
            }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            if status == errSecMissingEntitlement {
                #if DEBUG && !os(watchOS)
                if let val = runOnMainSync({ keyStore?.string(forKey: key) }) {
                    return val
                }
                #endif
            }
            throw KeychainError.retrieveFailed(status)
        }
    }

    /// 删除敏感数据
    /// - Parameter key: 键名
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        #if DEBUG && !os(watchOS)
        // 在 DEBUG 模式下，无论 Keychain 删除结果如何，都同步清理 KeyStore 回退缓存
        runOnMainSync { keyStore?.removeObject(forKey: key) }
        #endif
        guard status == errSecSuccess || status == errSecItemNotFound else {
            if status == errSecMissingEntitlement {
                return
            }
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: LocalizedError {
    case encodingFailed
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedData

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode value for Keychain storage"
        case .storeFailed(let status):
            return "Keychain store" + " failed: \(status)"
        case .retrieveFailed(let status):
            return "Keychain retrieve" + " failed: \(status)"
        case .deleteFailed(let status):
            return "Keychain delete" + " failed: \(status)"
        case .unexpectedData:
            return "Keychain returned unexpected data format"
        }
    }
}

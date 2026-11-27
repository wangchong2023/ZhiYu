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
    /// 默认单例
    private static let _defaultShared = KeychainService()
    /// 全局单例入口：优先从 DI 容器解析已注册实例，否则使用默认单例
    static var shared: KeychainService {
        // inject_exempt: 静态单例优先从 DI 解析已注册实例，否则 fallback 默认单例（冷启动降级）
        ServiceContainer.shared.resolveOptional(KeychainService.self) ?? _defaultShared
    }
    /// Keychain 服务标识符
    private let serviceName: String
    /// 缺失 keychain entitlement 时的独立隔离套件存储（避免直接访问 UserDefaults.standard）
    private let fallbackDefaults: UserDefaults

    private enum Namespace {
        static let production = "com.zhiyu.keychain"
        static let fallbackPrefix = "com.zhiyu.keychain.fallback."
        static let fallbackSuiteSuffix = ".fallback"
    }

    /// 保持既有正式命名空间，独立应用可通过构造参数隔离凭据。
    init(serviceName: String? = nil) {
        let resolvedName = serviceName ?? Namespace.production
        self.serviceName = resolvedName
        self.fallbackDefaults = UserDefaults(suiteName: resolvedName + Namespace.fallbackSuiteSuffix) ?? UserDefaults()
    }

    /// 本地无签名 / 缺失 keychain-access-groups entitlement 时的回退存储键
    private func fallbackKey(for key: String) -> String {
        "\(Namespace.fallbackPrefix)\(serviceName).\(key)"
    }

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

        let baseQuery = KeychainQueryHelper.baseQuery(serviceName: serviceName, key: key)
        let extra: [String: Any] = [
            kSecValueData as String: data,
            // VULN-012 修复：改用 WhenUnlockedThisDeviceOnly，禁止 iCloud/itunes 备份提取
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let query = baseQuery.merging(extra) { _, new in new }
        var status = SecItemAdd(query as CFDictionary, nil)
        // 并发写入场景下若另一线程恰好在 delete 与 add 之间完成了插入，原子降级为 SecItemUpdate 覆盖更新
        if status == errSecDuplicateItem {
            status = SecItemUpdate(baseQuery as CFDictionary, extra as CFDictionary)
        }
        // 无签名本地调试/测试宿主缺失 keychain-access-groups entitlement 时，
        // 避免回退到传统登录钥匙串触发反复弹窗，改用本地隔离回退存储。
        if status == errSecMissingEntitlement {
            fallbackDefaults.set(value, forKey: fallbackKey(for: key))
            return
        }
        guard status == errSecSuccess else {
            Logger.shared.error(" [KeychainService]  (\(key)): \(status)")
            throw KeychainError.storeFailed(status)
        }
    }

    /// 获取敏感数据
    /// - Parameter key: 键名
    /// - Returns: 存储的字符串，不存在则返回 nil
    func retrieve(key: String) throws -> String? {
        let extra: [String: Any] = [
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        let query = KeychainQueryHelper.baseQuery(serviceName: serviceName, key: key)
            .merging(extra) { _, new in new }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecMissingEntitlement {
            return fallbackDefaults.string(forKey: fallbackKey(for: key))
        }

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.unexpectedData
            }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.retrieveFailed(status)
        }
    }

    /// 删除敏感数据
    /// - Parameter key: 键名
    func delete(key: String) throws {
        let query = KeychainQueryHelper.baseQuery(serviceName: serviceName, key: key)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecMissingEntitlement {
            fallbackDefaults.removeObject(forKey: fallbackKey(for: key))
            return
        }
        guard status == errSecSuccess || status == errSecItemNotFound else {
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

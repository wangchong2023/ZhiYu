//
//  KeyStoreProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/07/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：键值存储抽象协议 — 统一 UserDefaults / iCloud KVS / 测试 Mock 访问。

import Foundation
import Dependencies
import UFPCore

/// 键值存储抽象协议
///
/// 为 UserDefaults.standard 提供协议化抽象层，支持：
/// - 生产环境：UserDefaultsKeyStore（标准 UserDefaults）
/// - iCloud：NSUbiquitousKeyValueStore 适配（未来）
/// - 测试环境：MockKeyStore（内存实现）
public protocol KeyStoreProtocol: AnyObject, Sendable {
    func bool(forKey key: String) -> Bool
    func string(forKey key: String) -> String?
    func data(forKey key: String) -> Data?
    func integer(forKey key: String) -> Int
    func double(forKey key: String) -> Double
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func set(_ value: Bool, forKey key: String)
    func removeObject(forKey key: String)
    func dictionaryRepresentation() -> [String: Any]
}

// MARK: - DependencyKey 注册

/// KeyStoreProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析，可选）
public enum KeyStoreKey: DependencyKey {
    nonisolated public static var liveValue: (any KeyStoreProtocol)? {
        ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
    }
    nonisolated public static var testValue: (any KeyStoreProtocol)? {
        // 测试环境优先从 ServiceContainer 解析（已注册 mock 时使用 mock），
        // 未注册时回退到 UserDefaultsKeyStore.shared，保持与迁移前 UserDefaults.standard 行为一致
        ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) ?? UserDefaultsKeyStore.shared
    }
    nonisolated public static var previewValue: (any KeyStoreProtocol)? { nil }
}

extension DependencyValues {
    /// 键值存储服务依赖（可选，DI 未就绪时返回 nil）
    public var keyStore: (any KeyStoreProtocol)? {
        get { self[KeyStoreKey.self] }
        set { self[KeyStoreKey.self] = newValue }
    }
}

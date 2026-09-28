//
//  UserDefaultsKeyStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/07/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：UserDefaults 标准实现，适配 TestFlight / AppStore / 开发环境。

import Foundation

/// UserDefaults 标准实现
///
/// 将 UserDefaults.standard 封装为 KeyStoreProtocol 的适配器，
/// 支持通过构造函数注入自定义 UserDefaults 实例（如 App Group 共享容器）。
final class UserDefaultsKeyStore: KeyStoreProtocol, @unchecked Sendable {
    /// 全局共享实例
    static let shared = UserDefaultsKeyStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func bool(forKey key: String) -> Bool {
        defaults.bool(forKey: key)
    }

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func integer(forKey key: String) -> Int {
        defaults.integer(forKey: key)
    }

    func double(forKey key: String) -> Double {
        defaults.double(forKey: key)
    }

    func object(forKey key: String) -> Any? {
        defaults.object(forKey: key)
    }

    func set(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func removeObject(forKey key: String) {
        defaults.removeObject(forKey: key)
    }

    func dictionaryRepresentation() -> [String: Any] {
        defaults.dictionaryRepresentation()
    }
}

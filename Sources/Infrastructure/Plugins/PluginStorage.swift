//
//  PluginStorage.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：插件数据持久化存储，管理私有键值数据及封禁列表持久化。
//

import Foundation
import UFPCore
import Dependencies

/// 插件存储管理器：封装插件私有数据与封禁状态的持久化操作
@MainActor
final class PluginStorage {

    // MARK: - 插件数据持久化实例

    /// 底层数据存储委托
    private let dataStore = PluginDataStore()

    // MARK: - 封禁列表持久化

    @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?

    /// 从持久化存储加载已挂起的插件 ID 集合
    func loadSuspendedPluginIDs() -> Set<String> {
        guard let keyStore else { return [] }
        let saved = keyStore.object(forKey: AppConstants.Keys.Storage.suspendedPlugins) as? [String] ?? []
        return Set(saved)
    }

    /// 持久化已挂起的插件 ID 集合
    func saveSuspendedPluginIDs(_ ids: Set<String>) {
        guard let keyStore else { return }
        let array = Array(ids)
        keyStore.set(array, forKey: AppConstants.Keys.Storage.suspendedPlugins)
    }

    /// 清除封禁列表持久化
    func clearSuspendedPluginIDs() {
        guard let keyStore else { return }
        keyStore.removeObject(forKey: AppConstants.Keys.Storage.suspendedPlugins)
    }

    // MARK: - 插件私有数据

    /// 保存插件私有数据
    func savePluginData(pluginID: String, key: String, value: String) {
        dataStore.savePluginData(pluginID: pluginID, key: key, value: value)
    }

    /// 读取插件私有数据
    func loadPluginData(pluginID: String, key: String) -> String? {
        dataStore.loadPluginData(pluginID: pluginID, key: key)
    }

    /// 获取插件的所有持久化数据（解密后）
    func loadAllPluginData(pluginID: String) -> [String: String] {
        dataStore.loadAllPluginData(pluginID: pluginID)
    }
}

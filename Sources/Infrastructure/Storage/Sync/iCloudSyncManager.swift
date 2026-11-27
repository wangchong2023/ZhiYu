//
//  iCloudSyncManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：持久化引擎：GRDB/SQLite 仓库、同步、加密、数据库管理。
//
#if ICLOUD_ENABLED
import Foundation
import Combine
import Dependencies
import UFPCore

/// iCloud 配置同步管理器 (PM 视角：跨设备连续性)
/// 负责在设备间自动同步用户设置（如 LLM 配置、主题偏好等）。
@MainActor
final class iCloudSyncManager {
    static let shared = iCloudSyncManager()

    private let kvStore = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()

    /// 键值存储抽象（DI 注入，替代 UserDefaults.standard 直接访问）
    @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?

    private init() {
        setupSync()
    }

    /// 启动同步逻辑
    func setupSync() {
        // 1. 监听远程变更 (从 iCloud 拉取到本地)
        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .sink { [weak self] _ in
                self?.pullFromCloud()
            }
            .store(in: &cancellables)

        // 2. 初始同步
        kvStore.synchronize()
        pullFromCloud()

        // 3. 监听本地变更并推送 (在此可添加具体的 AppStorage 键名监听)
    }

    /// 仅允许通过 NSUbiquitousKeyValueStore 同步的非敏感偏好键白名单（严禁同步 API Key 等敏感凭据）
    private enum SyncKeys {
        static let allowedPreferenceKeys: [String] = ["llm_model", "llm_enabled", "llm_provider_type"]
        static let allowedPreferenceKeySet: Set<String> = Set(allowedPreferenceKeys)
    }

    /// 将云端非敏感偏好拉取到本地 KeyStore
    private func pullFromCloud() {
        for key in SyncKeys.allowedPreferenceKeys {
            if let cloudValue = kvStore.object(forKey: key) {
                keyStore?.set(cloudValue, forKey: key)
            }
        }
    }

    /// 将本地非敏感偏好同步至云端（拒绝敏感凭据写入 KVS）
    func pushToCloud(key: String, value: Any) {
        guard SyncKeys.allowedPreferenceKeySet.contains(key) else { return }
        kvStore.set(value, forKey: key)
        kvStore.synchronize()
    }
}
#endif // ICLOUD_ENABLED

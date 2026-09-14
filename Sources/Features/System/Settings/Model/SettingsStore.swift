//
//  SettingsStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：系统设置：LLM 配置、性能监控、插件管理、iCloud、备份。
//
import Foundation
import UFPCore
import Observation
import Combine
import Dependencies

/// 全局设置存储，管理隐私模式、安全验证及显示偏好。
@MainActor
@Observable
public final class SettingsStore {
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    // keyStore 已全部通过 resolveOptional() 手动解析，不再使用 @Inject 声明

    public init() {
        AppEventBus.shared.subscribe()
            .sink { [weak self] in if case .clearAllDataRequested = $0 { self?.reset() } }
            .store(in: &cancellables)
    }

    // MARK: - KeyStore 访问辅助

    /// 解析 KeyStore（DI 未就绪时返回 nil），消除重复的 resolveOptional 模式
    @ObservationIgnored
    private var keyStore: (any KeyStoreProtocol)? {
        ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
    }

    /// 读取 Bool 设置（DI 未就绪时返回 defaultValue），消除重复的 guard+resolveOptional+bool 模式
    private func boolSetting(for key: String, default defaultValue: Bool) -> Bool {
        guard let ks = keyStore else { return defaultValue }
        return ks.bool(forKey: key)
    }

    /// 读取 String 设置（DI 未就绪时返回 defaultValue），消除重复的 guard+resolveOptional+string 模式
    private func stringSetting(for key: String, default defaultValue: String) -> String {
        guard let ks = keyStore else { return defaultValue }
        return ks.string(forKey: key) ?? defaultValue
    }

    /// 写入设置（DI 未就绪时静默忽略），消除重复的 resolveOptional?.set 模式
    private func setSetting(_ value: Any, for key: String) {
        keyStore?.set(value, forKey: key) // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
    }

    /// 静态加载 Bool 设置（用于存储属性初始化闭包），消除 _isPrivacyModeEnabled 与 _isBiometricEnabled 的重复
    private static func loadBoolSetting(key: String, defaultValue: Bool) -> Bool {
        guard let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) else { // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
            return defaultValue
        }
        return keyStore.object(forKey: key) as? Bool ?? defaultValue
    }

    // ── 隐私与安全 ──
    /// 使用 resolveOptional 优雅降级：DI 容器未就绪（如单测 setUp 早期）时回退到默认 true。
    @ObservationIgnored private var _isPrivacyModeEnabled: Bool = loadBoolSetting(
        key: AppConstants.Keys.Storage.isPrivacyModeEnabled, defaultValue: true
    )

    public var isPrivacyModeEnabled: Bool {
        get {
            access(keyPath: \.isPrivacyModeEnabled)
            return _isPrivacyModeEnabled
        }
        set {
            withMutation(keyPath: \.isPrivacyModeEnabled) {
                _isPrivacyModeEnabled = newValue
                setSetting(newValue, for: AppConstants.Keys.Storage.isPrivacyModeEnabled)
            }
        }
    }

    @ObservationIgnored private var _isBiometricEnabled: Bool = loadBoolSetting(
        key: AppConstants.Keys.Storage.isBiometricEnabled, defaultValue: true
    )
    
    public var isBiometricEnabled: Bool {
        get {
            access(keyPath: \.isBiometricEnabled)
            return _isBiometricEnabled
        }
        set {
            withMutation(keyPath: \.isBiometricEnabled) {
                _isBiometricEnabled = newValue
                setSetting(newValue, for: AppConstants.Keys.Storage.isBiometricEnabled)
            }
        }
    }

    // ── 性能与调试 ──
    public var showPerfDashboard = false

    // ── 引导状态 ──
    public var hasShownGraphCoachMark: Bool {
        get { boolSetting(for: AppConstants.Keys.Storage.hasShownGraphCoachMark, default: false) }
        set { setSetting(newValue, for: AppConstants.Keys.Storage.hasShownGraphCoachMark) }
    }

    // ── iCloud 同步偏好 ──
    public var iCloudConflictResolution: String {
        get { stringSetting(for: AppConstants.Keys.Storage.iCloudConflictResolution, default: AppConstants.Storage.ConflictResolution.merge) }
        set { setSetting(newValue, for: AppConstants.Keys.Storage.iCloudConflictResolution) }
    }

    public var iCloudAutoSync: Bool {
        get { boolSetting(for: AppConstants.Keys.Storage.iCloudAutoSync, default: false) }
        set { setSetting(newValue, for: AppConstants.Keys.Storage.iCloudAutoSync) }
    }

    // ── 协作用户名 ──
    public var collabUsername: String {
        get { stringSetting(for: AppConstants.Keys.Storage.userName, default: "") }
        set { setSetting(newValue, for: AppConstants.Keys.Storage.userName) }
    }

    /// 重置
    public func reset() {
        isPrivacyModeEnabled = true
        isBiometricEnabled = true
        showPerfDashboard = false
        hasShownGraphCoachMark = false
        guard let ks = keyStore else { return } // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
        ks.removeObject(forKey: AppConstants.Keys.Storage.iCloudConflictResolution)
        ks.removeObject(forKey: AppConstants.Keys.Storage.iCloudAutoSync)
        ks.removeObject(forKey: AppConstants.Keys.Storage.userName)
    }
}

// MARK: - DependencyKey

extension SettingsStore: DependencyKey {
    public static var liveValue: SettingsStore {
        ServiceContainer.shared.resolveOptional(SettingsStore.self) ?? SettingsStore()
    }
    public static var testValue: SettingsStore {
        ServiceContainer.shared.resolveOptional(SettingsStore.self) ?? SettingsStore()
    }
}

extension DependencyValues {
    /// 系统设置存储依赖
    public var settingsStore: SettingsStore {
        get { self[SettingsStore.self] }
        set { self[SettingsStore.self] = newValue }
    }
}

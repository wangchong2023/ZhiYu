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
    // ── 隐私与安全 ──
    /// 使用 resolveOptional 优雅降级：DI 容器未就绪（如单测 setUp 早期）时回退到默认 true。
    @ObservationIgnored private var _isPrivacyModeEnabled: Bool = {
        guard let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) else { // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
            return true
        }
        return keyStore.object(forKey: AppConstants.Keys.Storage.isPrivacyModeEnabled) as? Bool ?? true
    }()

    public var isPrivacyModeEnabled: Bool {
        get {
            access(keyPath: \.isPrivacyModeEnabled)
            return _isPrivacyModeEnabled
        }
        set {
            withMutation(keyPath: \.isPrivacyModeEnabled) {
                _isPrivacyModeEnabled = newValue
                ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)?.set(newValue, forKey: AppConstants.Keys.Storage.isPrivacyModeEnabled) // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
            }
        }
    }

    @ObservationIgnored private var _isBiometricEnabled: Bool = {
        guard let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) else { // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
            return true
        }
        return keyStore.object(forKey: AppConstants.Keys.Storage.isBiometricEnabled) as? Bool ?? true
    }()
    
    public var isBiometricEnabled: Bool {
        get {
            access(keyPath: \.isBiometricEnabled)
            return _isBiometricEnabled
        }
        set {
            withMutation(keyPath: \.isBiometricEnabled) {
                _isBiometricEnabled = newValue
                ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)?.set(newValue, forKey: AppConstants.Keys.Storage.isBiometricEnabled) // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
            }
        }
    }

    // ── 性能与调试 ──
    public var showPerfDashboard = false

    // ── 引导状态 ──
    public var hasShownGraphCoachMark: Bool {
        get {
            guard let ks = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) else { return false } // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
            return ks.bool(forKey: AppConstants.Keys.Storage.hasShownGraphCoachMark)
        }
        set { ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)?.set(newValue, forKey: AppConstants.Keys.Storage.hasShownGraphCoachMark) } // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
    }

    // ── iCloud 同步偏好 ──
    public var iCloudConflictResolution: String {
        get {
            guard let ks = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) else { return "merge" } // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
            return ks.string(forKey: AppConstants.Keys.Storage.iCloudConflictResolution) ?? "merge"
        }
        set { ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)?.set(newValue, forKey: AppConstants.Keys.Storage.iCloudConflictResolution) } // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
    }

    public var iCloudAutoSync: Bool {
        get {
            guard let ks = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) else { return false } // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
            return ks.bool(forKey: AppConstants.Keys.Storage.iCloudAutoSync)
        }
        set { ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)?.set(newValue, forKey: AppConstants.Keys.Storage.iCloudAutoSync) } // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
    }

    // ── 协作用户名 ──
    public var collabUsername: String {
        get {
            guard let ks = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) else { return "" } // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
            return ks.string(forKey: AppConstants.Keys.Storage.userName) ?? ""
        }
        set { ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)?.set(newValue, forKey: AppConstants.Keys.Storage.userName) } // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
    }

    /// 重置
    public func reset() {
        isPrivacyModeEnabled = true
        isBiometricEnabled = true
        showPerfDashboard = false
        hasShownGraphCoachMark = false
        guard let ks = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) else { return } // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
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

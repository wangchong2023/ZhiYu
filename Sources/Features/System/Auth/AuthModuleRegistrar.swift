//
//  AuthModuleRegistrar.swift
//  ZhiYu
//
//  系统层级：[L2] 领域层 — 认证与库服务注册
//  核心职责：注册认证、保险库、设置存储等系统级领域服务
//  依赖：StorageModuleRegistrar (L1) 已完成
//

import Foundation

// MARK: - 认证与系统模块 (L2)

/// 认证模块注册器：负责 Auth、Vault、Settings 等系统核心服务
@MainActor
struct AuthModuleRegistrar: ModuleRegistrar {

    /// 注册认证与库服务 (@SR-03: 集成 LocalAuthentication)
    static func register(in container: ServiceContainer) {
        Logger.shared.info("[DI] Starting registration of auth & system modules...")

        container.register(AuthService.shared as any AuthServiceProtocol, for: (any AuthServiceProtocol).self)
        container.register(VaultService.shared as any VaultServiceProtocol, for: (any VaultServiceProtocol).self)
        container.register(AuthService.shared, for: AuthService.self)
        container.register(VaultService.shared, for: VaultService.self)
        // 提前实例化并注册全局唯一的设置存储中心，供 AppStore 及各层级视图 @Inject 调用，彻底阻断循环依赖评估闪退 (@SRP)
        container.register(SettingsStore(), for: SettingsStore.self)

        Logger.shared.info("[DI] Auth & system module registration completed")
    }
}

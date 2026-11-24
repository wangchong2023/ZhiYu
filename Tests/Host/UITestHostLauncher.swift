//
//  UITestHostLauncher.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试基础设施
//  核心职责：仅在测试应用中安装依赖、准备状态并启动共用业务场景。
//
import SwiftUI
import Dependencies
import UFPCore
#if canImport(UIKit)
import UIKit
#endif

@main
struct UITestHostLauncher {
    @MainActor
    static func main() throws {
        try UITestBootstrap.prepare()
        if CommandLine.arguments.contains(UITestConstants.storageProbe) {
            StorageIsolationProbeApp.main()
        } else {
            ZhiYuApp.main()
        }
    }
}

/// 所有自动化参数的解释权限定在测试应用，不进入正式 target。
@MainActor
enum UITestBootstrap {
    static func prepare() throws {
        let container = ServiceContainer.shared
        let defaults = UserDefaults.standard
        let keyStore = UserDefaultsKeyStore(defaults: defaults)
        let injectedToken = ProcessInfo.processInfo.environment[UITestConstants.accessToken]
        let keychain: KeychainService
        if let injectedToken, !injectedToken.isEmpty {
            keychain = KeychainService(serviceName: UITestConstants.keychainService)
        } else {
            keychain = UITestMemoryKeychainService(serviceName: UITestConstants.keychainService)
        }
        container.register(keyStore as any KeyStoreProtocol, for: (any KeyStoreProtocol).self)
        container.register(keychain, for: KeychainService.self)
        container.register(FeatureGateManager(userDefaults: defaults, allowsGuestAccess: true), for: FeatureGateManager.self)
        container.register(EphemeralDatabaseBootstrapStrategy() as any DatabaseBootstrapStrategy, for: (any DatabaseBootstrapStrategy).self)
        container.register(ApplicationStorageLocation(root: UITestConstants.storageRoot), for: ApplicationStorageLocation.self)

        // 重置仅作用于独立测试 bundle 的偏好设置及凭据，不清理正式应用的数据。
        if CommandLine.arguments.contains(UITestConstants.resetAuth) {
            defaults.removeObject(forKey: AppConstants.Keys.Storage.authIsAuthenticated)
            defaults.removeObject(forKey: AppConstants.Keys.Storage.authIsGuest)
            try keychain.delete(key: AppConstants.Network.jwtTokenKey)
            try keychain.delete(key: AppConstants.Network.refreshTokenKey)
        }
        if CommandLine.arguments.contains(UITestConstants.resetDefaults) {
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(UITestConstants.seedPrefix) {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.set(true, forKey: AppConstants.Keys.Storage.hasSeenSplashBefore)
        if CommandLine.arguments.contains(UITestConstants.skipOnboarding) {
            defaults.set(true, forKey: AppConstants.Keys.Storage.hasCompletedOnboarding)
        }

        // Token 写入失败直接终止启动，避免真实后端用例静默退化成游客测试。
        if let token = ProcessInfo.processInfo.environment[UITestConstants.accessToken], !token.isEmpty {
            try keychain.store(key: AppConstants.Network.jwtTokenKey, value: token)
        } else if !CommandLine.arguments.contains(UITestConstants.resetAuth) {
            AuthSession.shared.isGuest = true
        }
        prepareDependencies {
            $0.vaultSelectionPolicy = UITestVaultSelectionPolicy()
            $0.vaultBadgeInteractionPolicy = UITestVaultBadgeInteractionPolicy()
            $0.navigationLayoutPolicy = UITestNavigationLayoutPolicy()
            $0.autoLoginPolicy = UITestAutoLoginPolicy()
            $0.vaultSeedingPolicy = UITestVaultSeedingPolicy()
        }
        #if canImport(UIKit)
        UIView.setAnimationsEnabled(false)
        #endif
        let environment = AppEnvironment.shared
        if CommandLine.arguments.contains(UITestConstants.mockData) {
            let configuration = environment.llmConfig
            configuration.apiKey = UITestConstants.offlineAPIKey
            configuration.isEnabled = true
            configuration.autoScan = false
            configuration.autoRefactor = false
            container.register(UITestChatService() as any LLMChatServiceProtocol, for: (any LLMChatServiceProtocol).self)
        }
        if let route = UITestRoute.fromLaunchArguments() {
            Task { @MainActor in
                route.apply(to: AppEnvironment.shared.router)
            }
        }
    }
}

/// 独立测试命名空间集中管理，禁止复用正式存储服务标识。
enum UITestConstants {
    static let storageProbe = "--verify-storage-isolation"
    static let mockData = "-UITest_MockData"
    static let offlineAPIKey = "offline-ui-test-key"
    static let resetAuth = "--reset-auth-state"
    static let resetDefaults = "-ResetUserDefaults"
    static let skipOnboarding = "--skip-onboarding"
    static let seedPrefix = "seeded_vault_"
    static let accessToken = "UITest_InjectAccessToken"
    static var keychainService: String {
        (Bundle.main.bundleIdentifier ?? "top.izhiyu.testing.ui") + ".keychain"
    }
    static let storageRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("ZhiYuUITestStorage", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

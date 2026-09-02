//
//  VaultStorageSecurityService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 VaultStorageSecurity 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
import Dependencies
import LocalAuthentication
import Observation

@MainActor
@Observable
final class VaultStorageSecurityService {
    /// 当前笔记本是否处于锁定状态（UI 应据此显示遮罩或锁定视图）
    var isLocked = false

    /// 当前硬件环境是否支持并已配置生物识别（FaceID/TouchID）
    private var _biometricsAvailable: Bool?
    var biometricsAvailable: Bool {
        if let existing = _biometricsAvailable {
            return existing
        }
        checkBiometrics()
        return _biometricsAvailable ?? false
    }

    /// 注入的平台策略提供者（过渡期：每次从 ServiceContainer 解析，确保测试中重新注册生效）
    private var provider: any BiometricAuthProviderProtocol {
        ServiceContainer.shared.resolveOptional((any BiometricAuthProviderProtocol).self) ?? NoOpBiometricAuthProvider() // inject_exempt
    }

    /**
     * @description: 初始化安全服务
     * @return {*}
     */
    init() {
        // 不再在 init 中调用 checkBiometrics，推迟到首次使用时
    }

    /// 暂存当前的认证上下文，防止闭包回调前被释放导致闪退
    private var activeContext: LAContext?

    /**
     * @description: 检查并更新当前设备的生物识别可用性状态
     * @return {*}
     */

    /// 检查Biometrics
    func checkBiometrics() {
        let context = LAContext()
        _biometricsAvailable = provider.canEvaluatePolicy(context: context)
    }

    /**
     * @description: 异步触发生物识别解锁流程，成功后更新 isLocked 状态并返回结果
     * @return {Bool} 是否解锁成功
     */

    /// unlock
    /// - Returns: 是否成功
    func unlock() async -> Bool {
        let success = await authenticateWithBiometrics()
        if success {
            self.isLocked = false
            HapticFeedback.shared.trigger(.unlock)
        } else {
            HapticFeedback.shared.trigger(.error)
        }
        return success
    }

    /**
     * @description: 执行一次性生物识别认证，常用于切换安全开关或验证操作权限
     * @return {Bool} 认证是否成功。注意：若硬件不支持则默认返回 true 以免逻辑死锁
     */

    /// 认证WithBiometrics
    /// - Returns: 是否成功
    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        self.activeContext = context // 保持引用
        
        guard provider.canEvaluatePolicy(context: context) else {
            self.activeContext = nil
            return true
        }

        let result = await provider.evaluatePolicy(context: context, reason: L10n.Common.Security.unlockReason)

        self.activeContext = nil
        return result
    }

    /**
     * @description: 立即锁定笔记本，更新 isLocked 状态并触发震动反馈
     * @return {*}
     */

    /// lock
    func lock() {
        isLocked = true
        HapticFeedback.shared.trigger(.lock)
    }
}

// MARK: - DependencyKey 注册

/// VaultStorageSecurityService 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
@MainActor
enum VaultStorageSecurityServiceKey: DependencyKey {
    @MainActor
    static var liveValue: VaultStorageSecurityService {
        ServiceContainer.shared.resolve(VaultStorageSecurityService.self)
    }
    @MainActor
    static var testValue: VaultStorageSecurityService {
        ServiceContainer.shared.resolveOptional(VaultStorageSecurityService.self) ?? VaultStorageSecurityService()
    }
    @MainActor
    static var previewValue: VaultStorageSecurityService { testValue }
}

extension DependencyValues {
    /// Vault 存储安全服务依赖
    var vaultStorageSecurityService: VaultStorageSecurityService {
        get { self[VaultStorageSecurityServiceKey.self] }
        set { self[VaultStorageSecurityServiceKey.self] = newValue }
    }
}

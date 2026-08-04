//
//  VaultSecurityTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 VaultSecurity 开展自动化单元测试验证。
//
import XCTest
import UFPCore
import LocalAuthentication
@testable import ZhiYu

/// Mock 生物识别提供者，用于控制测试环境下的认证结果
@MainActor
struct VaultSecurityMockBiometricAuthProvider: BiometricAuthProviderProtocol {
    /// 模拟的生物识别是否可用
    var isAvailable: Bool = true
    /// 模拟的安全鉴权是否成功
    var shouldAuthSucceed: Bool = true
    /// 模拟硬件延迟时间
    var evaluateDelay: TimeInterval = 0.01
    
    /// 鉴权策略，默认使用设备所有者生物识别鉴权
    var authenticationPolicy: LAPolicy { .deviceOwnerAuthenticationWithBiometrics }
    
    /// 检查生物识别是否可用
    /// - Parameter context: 本地鉴权上下文
    /// - Returns: 是否可用
    func canEvaluatePolicy(context: LAContext) -> Bool {
        return isAvailable
    }
    
    /// 执行生物识别鉴权
    /// - Parameters:
    ///   - context: 本地鉴权上下文
    ///   - reason: 鉴权原因
    /// - Returns: 是否鉴权成功
    func evaluatePolicy(context: LAContext, reason: String) async -> Bool {
        try? await Task.sleep(nanoseconds: UInt64(evaluateDelay * 1_000_000_000))
        return shouldAuthSucceed
    }
}

/// Mock 触感反馈，防止测试中崩溃
struct MockHapticFeedback: HapticFeedbackProtocol {
    func trigger(_ pattern: HapticPattern) {}
}

/// 金库安全服务测试
/// 验证 VaultSecurityService 的锁定/解锁状态切换及生物识别可用性检测。
@MainActor
final class VaultSecurityTests: XCTestCase {

    var vault: VaultStorageSecurityService!
    var mockProvider: VaultSecurityMockBiometricAuthProvider!

    override func setUp() async throws {
        try await super.setUp()
        // 1. 调用全局 Mock 环境注册一整套基础依赖，规避由于依赖不全导致的套娃式 DI 崩溃
        setupFullMockEnvironment()
        
        // 2. 覆盖注册 VaultSecurityTests 专属的特化 Mock 服务
        ServiceContainer.shared.register(MockHapticFeedback() as any HapticFeedbackProtocol, for: (any HapticFeedbackProtocol).self)
        
        mockProvider = VaultSecurityMockBiometricAuthProvider()
        ServiceContainer.shared.register(mockProvider, for: BiometricAuthProviderProtocol.self)
        
        vault = VaultStorageSecurityService()
    }

    override func tearDown() async throws {
        vault = nil
        mockProvider = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialStateIsUnlocked() {
        XCTAssertFalse(vault.isLocked, "金库初始状态应为未锁定")
    }

    func testBiometricsAvailabilityIsCheckedOnInit() {
        let available = vault.biometricsAvailable
        XCTAssertTrue(available, "由于 mockProvider isAvailable=true，生物识别应为可用")
        
        // 测试不可用状态
        mockProvider.isAvailable = false
        ServiceContainer.shared.register(mockProvider, for: BiometricAuthProviderProtocol.self)
        let newVault = VaultStorageSecurityService()
        XCTAssertFalse(newVault.biometricsAvailable, "注入不可用的 provider 后应反映其状态")
    }

    // MARK: - 锁定

    func testLockSetsIsLockedToTrue() {
        vault.lock()
        XCTAssertTrue(vault.isLocked, "lock() 后 isLocked 应为 true")
    }

    func testMultipleLockCallsStayLocked() {
        vault.lock()
        vault.lock()
        XCTAssertTrue(vault.isLocked, "多次 lock() 后仍应保持锁定状态")
    }

    // MARK: - 状态复位

    func testUnlockAfterLockResetsState() {
        vault.lock()
        XCTAssertTrue(vault.isLocked)

        vault.isLocked = false
        XCTAssertFalse(vault.isLocked, "解锁后 isLocked 应为 false")
    }

    func testLockUnlockCycle() {
        for _ in 0..<5 {
            vault.lock()
            XCTAssertTrue(vault.isLocked)
            vault.isLocked = false
            XCTAssertFalse(vault.isLocked)
        }
    }

    // MARK: - 生物识别交互

    func testAuthenticateWithBiometricsReturnsTrueIfNoProvider() async {
        // 配置一个不支持生物识别的 Provider
        mockProvider.isAvailable = false
        ServiceContainer.shared.register(mockProvider, for: BiometricAuthProviderProtocol.self)
        
        let result = await vault.authenticateWithBiometrics()
        XCTAssertTrue(result, "在无硬件或未配置策略时，应返回 true 以免死锁")
    }
    
    func testAuthenticateWithBiometricsSuccess() async {
        mockProvider.shouldAuthSucceed = true
        let result = await vault.authenticateWithBiometrics()
        XCTAssertTrue(result, "在 Mock 成功环境下，认证应当成功返回 true")
    }
    
    func testAuthenticateWithBiometricsFailure() async {
        mockProvider.shouldAuthSucceed = false
        // 重新注册更新状态的 mock (结构体需要重新注册)
        ServiceContainer.shared.register(mockProvider, for: BiometricAuthProviderProtocol.self)
        
        let result = await vault.authenticateWithBiometrics()
        XCTAssertFalse(result, "在 Mock 失败环境下，认证应当失败返回 false")
    }
    
    func testUnlockSuccessSetsIsLockedToFalse() async {
        vault.lock()
        XCTAssertTrue(vault.isLocked)
        
        mockProvider.shouldAuthSucceed = true
        ServiceContainer.shared.register(mockProvider, for: BiometricAuthProviderProtocol.self)
        
        let result = await vault.unlock()
        XCTAssertTrue(result, "解锁方法应当返回 true")
        XCTAssertFalse(vault.isLocked, "成功解锁后，isLocked 状态应被翻转为 false")
    }
    
    func testUnlockFailureKeepsIsLockedTrue() async {
        vault.lock()
        XCTAssertTrue(vault.isLocked)
        
        mockProvider.shouldAuthSucceed = false
        ServiceContainer.shared.register(mockProvider, for: BiometricAuthProviderProtocol.self)
        
        let result = await vault.unlock()
        XCTAssertFalse(result, "失败的解锁应当返回 false")
        XCTAssertTrue(vault.isLocked, "解锁失败后，金库仍应处于锁定状态")
    }
}

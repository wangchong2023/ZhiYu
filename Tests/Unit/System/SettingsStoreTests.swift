//
//  SettingsStoreTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/05/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 SettingsStore 系统偏好设置存储中心开展全面的单元测试验证。
//

import XCTest
import UFPCore
@testable import ZhiYu

/// 系统设置与偏好存储单元测试类（SettingsStoreTests）
/// 专职验证 `SettingsStore` 的数据读写持久化、观察者机制以及一键重置逻辑。
@MainActor
final class SettingsStoreTests: XCTestCase {
    
    /// 测试专用的 SettingsStore 实例
    private var settingsStore: SettingsStore!
    
    /// 在每次测试执行前清空并搭建纯净的 UserDefaults 隔离环境
    override func setUp() async throws {
        try await super.setUp()
        // 注册 KeyStoreProtocol 以支持设置持久化验证
        setupFullMockEnvironment()
        settingsStore = SettingsStore()

        // 抹除可能残留的 UserDefaults 偏好数据，防止测试用例之间产生状态污染
        settingsStore.reset()
    }
    
    /// 在每次测试后清空资源
    override func tearDown() async throws {
        settingsStore.reset()
        settingsStore = nil
        try await super.tearDown()
    }
    
    // MARK: - 核心测试用例
    
    /// 测试核心业务：验证系统偏好设置的初始默认值完全符合产品规格书定义。
    func testInitialDefaultSettings() {
        XCTAssertTrue(settingsStore.isPrivacyModeEnabled, "默认情况下隐私模式应当默认开启")
        XCTAssertTrue(settingsStore.isBiometricEnabled, "默认情况下生物识别应当默认开启")
        XCTAssertFalse(settingsStore.showPerfDashboard, "默认情况下性能监控面板应当默认关闭")
        XCTAssertFalse(settingsStore.hasShownGraphCoachMark, "默认情况下图谱新手教练标记应当为 false")
        XCTAssertEqual(settingsStore.iCloudConflictResolution, "merge", "默认 iCloud 冲突策略应当为 merge")
        XCTAssertFalse(settingsStore.iCloudAutoSync, "默认 iCloud 自动同步应当为 false")
        XCTAssertEqual(settingsStore.collabUsername, "", "默认协作用户名应当为空字符串")
    }
    
    /// 测试核心业务：验证修改各项设置属性时，数据能够正确且安全地持久化写入 UserDefaults 存储引擎中。
    func testSettingsModificationAndPersistence() {
        // P2-1 迁移：SettingsStore 通过 ServiceContainer 解析 KeyStoreProtocol，
        //           setupFullMockEnvironment() 注册的是独立 UserDefaults 实例，
        //           因此断言应从同一 KeyStore 读取，而非 UserDefaults.standard。
        let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)

        // 1. 修改并验证隐私与安全设置
        settingsStore.isPrivacyModeEnabled = false
        XCTAssertFalse(settingsStore.isPrivacyModeEnabled, "修改隐私模式状态应当成功")
        XCTAssertFalse(keyStore?.bool(forKey: AppConstants.Keys.Storage.isPrivacyModeEnabled) ?? true, "UserDefaults 中的对应值也应当同步为 false")

        settingsStore.isBiometricEnabled = false
        XCTAssertFalse(settingsStore.isBiometricEnabled, "修改生物识别状态应当成功")
        XCTAssertFalse(keyStore?.bool(forKey: AppConstants.Keys.Storage.isBiometricEnabled) ?? true, "UserDefaults 中的对应值也应当同步为 false")

        // 2. 修改并验证 iCloud 偏好
        settingsStore.iCloudConflictResolution = "keepLocal"
        XCTAssertEqual(settingsStore.iCloudConflictResolution, "keepLocal", "修改 iCloud 冲突策略应当成功")
        XCTAssertEqual(keyStore?.string(forKey: AppConstants.Keys.Storage.iCloudConflictResolution), "keepLocal", "UserDefaults 中的冲突策略值应当同步写入")

        settingsStore.iCloudAutoSync = true
        XCTAssertTrue(settingsStore.iCloudAutoSync, "启用 iCloud 自动同步应当成功")
        XCTAssertTrue(keyStore?.bool(forKey: AppConstants.Keys.Storage.iCloudAutoSync) ?? false, "UserDefaults 中的自动同步值应当同步写入")

        // 3. 修改并验证协作信息
        settingsStore.collabUsername = "Antigravity Architect"
        XCTAssertEqual(settingsStore.collabUsername, "Antigravity Architect", "修改协作用户名应当成功")
        XCTAssertEqual(keyStore?.string(forKey: AppConstants.Keys.Storage.userName), "Antigravity Architect", "UserDefaults 中的协作用户名应当同步写入")

        // 4. 修改调试配置
        settingsStore.showPerfDashboard = true
        XCTAssertTrue(settingsStore.showPerfDashboard, "启用性能面板状态应当成功")
    }
    
    /// 测试核心业务：验证调用 reset() 一键重置开发/系统配置时，所有存储选项能够安全干净地复位为初始值。
    func testSettingsResetLogic() {
        // 1. 先写入非默认测试值
        settingsStore.isPrivacyModeEnabled = false
        settingsStore.isBiometricEnabled = false
        settingsStore.showPerfDashboard = true
        settingsStore.hasShownGraphCoachMark = true
        settingsStore.iCloudConflictResolution = "keepCloud"
        settingsStore.iCloudAutoSync = true
        settingsStore.collabUsername = "Tester"
        
        // 2. 执行一键复位
        settingsStore.reset()
        
        // 3. 验证所有属性完全复归为产品默认状态值
        XCTAssertTrue(settingsStore.isPrivacyModeEnabled, "重置后隐私模式应当恢复默认开启")
        XCTAssertTrue(settingsStore.isBiometricEnabled, "重置后生物识别应当恢复默认开启")
        XCTAssertFalse(settingsStore.showPerfDashboard, "重置后性能面板应当恢复默认关闭")
        XCTAssertFalse(settingsStore.hasShownGraphCoachMark, "重置后新手教练标记应当恢复为 false")
        XCTAssertEqual(settingsStore.iCloudConflictResolution, "merge", "重置后iCloud冲突解决偏好应当重置为 merge")
        XCTAssertFalse(settingsStore.iCloudAutoSync, "重置后iCloud自动同步应当重置为 false")
        XCTAssertEqual(settingsStore.collabUsername, "", "重置后协作用户名应当被擦除为空字符串")
    }
}

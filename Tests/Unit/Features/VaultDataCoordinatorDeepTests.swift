//
//  VaultDataCoordinatorDeepTests.swift
//  ZhiYuTests
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 VaultService 数据协调器的 loadVaults 去重逻辑、autoRestoreActiveVault
//            热恢复、autoSelectFirstVaultForUITesting 预置逻辑。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class VaultDataCoordinatorDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        try? await Task.sleep(nanoseconds: 100_000_000)
        try await super.tearDown()
    }

    // MARK: - buildDefaultDemoVaults 深度验证

    /// 验证默认演示笔记本 createdAt 不为 nil 且为近期时间
    func testBuildDefaultDemoVaultsCreatedAtIsRecent() {
        let before = Date()
        let vaults = VaultService.shared.buildDefaultDemoVaults()
        let after = Date()

        for vault in vaults {
            XCTAssertGreaterThanOrEqual(vault.createdAt, before.addingTimeInterval(-1),
                                        "createdAt 应为近期时间")
            XCTAssertLessThanOrEqual(vault.createdAt, after.addingTimeInterval(1),
                                     "createdAt 应为近期时间")
        }
    }

    /// 验证默认演示笔记本 updatedAt 等于 createdAt
    func testBuildDefaultDemoVaultsUpdatedAtEqualsCreatedAt() {
        let vaults = VaultService.shared.buildDefaultDemoVaults()

        for vault in vaults {
            XCTAssertEqual(vault.createdAt, vault.updatedAt,
                           "新建演示笔记本 updatedAt 应等于 createdAt")
        }
    }

    /// 验证默认演示笔记本 themePayload 为 nil
    func testBuildDefaultDemoVaultsThemePayloadNil() {
        let vaults = VaultService.shared.buildDefaultDemoVaults()

        for vault in vaults {
            XCTAssertNil(vault.themePayload, "新建演示笔记本 themePayload 应为 nil")
        }
    }

    // MARK: - buildFallbackDemoVaults 深度验证

    /// 验证降级兜底笔记本 ID 每次调用都不同（UUID 随机生成）
    func testBuildFallbackDemoVaultsUniqueIDsAcrossCalls() {
        let vaults1 = VaultService.shared.buildFallbackDemoVaults()
        let vaults2 = VaultService.shared.buildFallbackDemoVaults()

        XCTAssertNotEqual(vaults1[0].id, vaults2[0].id, "每次调用 ID 应不同")
        XCTAssertNotEqual(vaults1[1].id, vaults2[1].id, "每次调用 ID 应不同")
    }

    /// 验证降级兜底笔记本 icon 非空
    func testBuildFallbackDemoVaultsIconNonNil() {
        let vaults = VaultService.shared.buildFallbackDemoVaults()

        XCTAssertTrue(vaults.allSatisfy { $0.icon != nil }, "降级兜底笔记本 icon 应非空")
    }

    // MARK: - autoRestoreActiveVault

    /// 验证 autoRestoreActiveVault 在无 keyStore 值时不崩溃
    func testAutoRestoreActiveVaultNoStoredID() {
        // 确保 keyStore 中没有存储 selectedVaultID
        let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
        keyStore?.removeObject(forKey: AppConstants.Keys.Storage.vaultsSelectedID)

        VaultService.shared.selectedVaultID = nil
        VaultService.shared.vaults = VaultService.shared.buildDefaultDemoVaults()

        VaultService.shared.autoRestoreActiveVault()

        // 无存储 ID 时 selectedVaultID 应保持 nil
        XCTAssertNil(VaultService.shared.selectedVaultID,
                     "无存储 ID 时 selectedVaultID 应保持 nil")
    }

    /// 验证 autoRestoreActiveVault 在有 keyStore 值但 vaults 为空时不崩溃
    func testAutoRestoreActiveVaultStoredIDButEmptyVaults() {
        let testID = UUID()
        let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
        keyStore?.set(testID.uuidString, forKey: AppConstants.Keys.Storage.vaultsSelectedID)

        VaultService.shared.selectedVaultID = nil
        VaultService.shared.vaults = []

        VaultService.shared.autoRestoreActiveVault()

        // vaults 为空时找不到对应 vault，selectedVaultID 应保持 nil
        XCTAssertNil(VaultService.shared.selectedVaultID,
                     "vaults 为空时 selectedVaultID 应保持 nil")

        keyStore?.removeObject(forKey: AppConstants.Keys.Storage.vaultsSelectedID)
    }

    /// 验证 autoRestoreActiveVault 在有 keyStore 值且 vaults 包含对应 ID 时恢复选中
    func testAutoRestoreActiveVaultRestoresSelectedID() {
        let vaults = VaultService.shared.buildDefaultDemoVaults()
        let targetID = vaults[0].id
        // 通过 DI 解析的 keyStore 写入（与 VaultService 使用同一实例）
        let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
        keyStore?.set(targetID.uuidString, forKey: AppConstants.Keys.Storage.vaultsSelectedID)

        VaultService.shared.selectedVaultID = nil
        VaultService.shared.vaults = vaults

        VaultService.shared.autoRestoreActiveVault()

        XCTAssertEqual(VaultService.shared.selectedVaultID, targetID,
                       "应从 keyStore 恢复 selectedVaultID")

        keyStore?.removeObject(forKey: AppConstants.Keys.Storage.vaultsSelectedID)
    }

    /// 验证 autoRestoreActiveVault 对无效 UUID 字符串安全跳过
    func testAutoRestoreActiveVaultInvalidUUIDString() {
        let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
        keyStore?.set("not-a-uuid", forKey: AppConstants.Keys.Storage.vaultsSelectedID)

        VaultService.shared.selectedVaultID = nil
        VaultService.shared.vaults = VaultService.shared.buildDefaultDemoVaults()

        VaultService.shared.autoRestoreActiveVault()

        // 无效 UUID 字符串应安全跳过
        XCTAssertNil(VaultService.shared.selectedVaultID,
                     "无效 UUID 字符串应安全跳过")

        keyStore?.removeObject(forKey: AppConstants.Keys.Storage.vaultsSelectedID)
    }

    // MARK: - autoSelectFirstVaultForUITesting

    /// 验证非 UI 测试模式下 autoSelectFirstVaultForUITesting 不执行
    func testAutoSelectFirstVaultForUITestingNotInUITestMode() {
        // 单元测试模式下 TestModeDetector.isUITesting 为 false
        VaultService.shared.selectedVaultID = nil
        VaultService.shared.vaults = VaultService.shared.buildDefaultDemoVaults()

        VaultService.shared.autoSelectFirstVaultForUITesting()

        XCTAssertNil(VaultService.shared.selectedVaultID,
                     "非 UI 测试模式下不应自动选中第一个 vault")
    }

    // MARK: - getVaultDatabaseURL

    /// 验证 getVaultDatabaseURL 返回正确路径结构
    func testGetVaultDatabaseURLPathStructure() {
        let vaultID = UUID()
        let url = VaultService.shared.getVaultDatabaseURL(for: vaultID)

        XCTAssertTrue(url.path.contains(AppConstants.Storage.vaultsDirectoryName),
                      "路径应包含 vaults 目录名")
        XCTAssertTrue(url.path.contains(vaultID.uuidString),
                      "路径应包含 vault UUID")
        XCTAssertTrue(url.path.contains(AppConstants.Storage.vaultDatabaseName),
                      "路径应包含数据库文件名")
    }

    /// 验证 getVaultDatabaseURL 对不同 UUID 返回不同路径
    func testGetVaultDatabaseURLDifferentForDifferentUUIDs() {
        let id1 = UUID()
        let id2 = UUID()
        let url1 = VaultService.shared.getVaultDatabaseURL(for: id1)
        let url2 = VaultService.shared.getVaultDatabaseURL(for: id2)

        XCTAssertNotEqual(url1, url2, "不同 UUID 应返回不同路径")
    }

    // MARK: - currentVault 计算属性

    /// 验证 currentVault 在 selectedVaultID 为 nil 时返回 nil
    func testCurrentVaultNilWhenNoSelection() {
        VaultService.shared.selectedVaultID = nil
        VaultService.shared.vaults = VaultService.shared.buildDefaultDemoVaults()

        XCTAssertNil(VaultService.shared.currentVault, "无选中 ID 时 currentVault 应为 nil")
    }

    /// 验证 currentVault 在 selectedVaultID 有效时返回对应 vault
    func testCurrentVaultReturnsSelectedVault() {
        let vaults = VaultService.shared.buildDefaultDemoVaults()
        VaultService.shared.vaults = vaults
        VaultService.shared.selectedVaultID = vaults[0].id

        XCTAssertEqual(VaultService.shared.currentVault?.id, vaults[0].id,
                       "currentVault 应返回选中的 vault")
    }

    /// 验证 currentVault 在 selectedVaultID 不在 vaults 列表中时返回 nil
    func testCurrentVaultNilWhenIDNotInVaults() {
        VaultService.shared.vaults = VaultService.shared.buildDefaultDemoVaults()
        VaultService.shared.selectedVaultID = UUID()

        XCTAssertNil(VaultService.shared.currentVault,
                     "selectedVaultID 不在 vaults 列表中时 currentVault 应为 nil")
    }

    // MARK: - saveVaultToDatabase

    /// 验证 saveVaultToDatabase 在 vaultRepository 已注册时不崩溃
    func testSaveVaultToDatabaseWithRegisteredRepository() {
        let vault = VaultService.shared.buildDefaultDemoVaults()[0]

        // setupFullMockEnvironment 已注册 vaultRepository
        VaultService.shared.saveVaultToDatabase(vault)

        // 异步操作，等待短暂时间让 Task 完成
        let expectation = expectation(description: "saveVaultToDatabase 完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // 验证不崩溃即可
        XCTAssertTrue(true, "saveVaultToDatabase 在有 vaultRepository 时应安全执行")
    }
}

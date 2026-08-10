//
//  VaultLifecycleManagerTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 VaultService 生命周期管理 — 创建/删除/重命名/选择/退出笔记本。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class VaultLifecycleManagerTests: XCTestCase {

    private var service: VaultService { VaultService.shared }

    /// 安全获取第一个 vault（测试前置条件已 createVault，此处仅解包）
    private func firstVault() -> Vault {
        guard let vault = service.vaults.first else {
            XCTFail("vaults 不应为空")
            return Vault(id: UUID(), name: "", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil)
        }
        return vault
    }

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        // 重置单例状态
        service.vaults = []
        service.selectedVaultID = nil
    }

    override func tearDown() async throws {
        service.vaults = []
        service.selectedVaultID = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - createVault

    /// 验证 createVault 添加到 vaults 数组
    func testCreateVaultAppendsToList() {
        service.createVault(name: "新笔记本", icon: "book", description: "描述")
        XCTAssertEqual(service.vaults.count, 1)
        XCTAssertEqual(service.vaults.first?.name, "新笔记本")
    }

    /// 验证 createVault 生成唯一 UUID
    func testCreateVaultGeneratesUniqueID() {
        service.createVault(name: "A")
        service.createVault(name: "B")
        XCTAssertNotEqual(service.vaults[0].id, service.vaults[1].id)
    }

    /// 验证 createVault 默认 icon/description 为 nil
    func testCreateVaultDefaultIconDescriptionNil() {
        service.createVault(name: "默认")
        XCTAssertNil(service.vaults.first?.icon)
        XCTAssertNil(service.vaults.first?.description)
    }

    /// 验证 createVault pageCount 初始为 0
    func testCreateVaultPageCountZero() {
        service.createVault(name: "空本")
        XCTAssertEqual(service.vaults.first?.pageCount, 0)
    }

    /// 验证 createVault 设置 seeded 标记
    func testCreateVaultSetsSeededFlag() {
        service.createVault(name: "标记测试")
        let id = firstVault().id
        let key = "\(AppConstants.Keys.Storage.seededVaultPrefix)\(id.uuidString)"
        // keyStore 是 UserDefaultsKeyStore.shared，检查值
        let value = UserDefaults.standard.bool(forKey: key)
        XCTAssertTrue(value, "createVault 应设置 seeded 标记")
    }

    // MARK: - updateVault

    /// 验证 updateVault 更新名称/icon/description
    func testUpdateVaultUpdatesFields() {
        service.createVault(name: "原名", icon: "old", description: "旧描述")
        let id = firstVault().id

        service.updateVault(id: id, name: "新名", icon: "new", description: "新描述")

        let updated = service.vaults.first { $0.id == id }
        XCTAssertEqual(updated?.name, "新名")
        XCTAssertEqual(updated?.icon, "new")
        XCTAssertEqual(updated?.description, "新描述")
    }

    /// 验证 updateVault 更新 updatedAt 时间戳
    func testUpdateVaultUpdatesTimestamp() {
        service.createVault(name: "时间测试")
        let id = firstVault().id
        let originalUpdatedAt = firstVault().updatedAt

        // 等待一小段时间确保时间戳不同
        Thread.sleep(forTimeInterval: 0.01)
        service.updateVault(id: id, name: "更新", icon: nil, description: nil)

        let updated = service.vaults.first { $0.id == id }
        guard let updated = service.vaults.first(where: { $0.id == id }) else {
            XCTFail("未找到更新后的 vault")
            return
        }
        XCTAssertGreaterThan(updated.updatedAt, originalUpdatedAt)
    }

    /// 验证 updateVault 不存在的 ID 不崩溃
    func testUpdateVaultNonExistentIDNoCrash() {
        service.updateVault(id: UUID(), name: "不存在", icon: nil, description: nil)
        XCTAssertTrue(service.vaults.isEmpty)
    }

    // MARK: - renameVault

    /// 验证 renameVault 仅更新名称
    func testRenameVaultUpdatesName() {
        service.createVault(name: "旧名", icon: "icon", description: "desc")
        let id = firstVault().id

        service.renameVault(id: id, newName: "新名")

        let renamed = service.vaults.first { $0.id == id }
        XCTAssertEqual(renamed?.name, "新名")
        // icon/description 不变
        XCTAssertEqual(renamed?.icon, "icon")
        XCTAssertEqual(renamed?.description, "desc")
    }

    /// 验证 renameVault 不存在的 ID 不崩溃
    func testRenameVaultNonExistentIDNoCrash() {
        service.renameVault(id: UUID(), newName: "不存在")
        XCTAssertTrue(service.vaults.isEmpty)
    }

    // MARK: - selectVault / exitVault

    /// 验证 selectVault 设置 selectedVaultID
    func testSelectVaultSetsSelectedID() {
        service.createVault(name: "选中测试")
        let vault = firstVault()

        service.selectVault(vault)

        XCTAssertEqual(service.selectedVaultID, vault.id)
    }

    /// 验证 exitVault 清除 selectedVaultID
    func testExitVaultClearsSelectedID() {
        service.createVault(name: "退出测试")
        let vault = firstVault()
        service.selectVault(vault)
        XCTAssertEqual(service.selectedVaultID, vault.id)

        service.exitVault()

        XCTAssertNil(service.selectedVaultID)
    }

    // MARK: - deleteVault

    /// 验证 deleteVault 从 vaults 数组移除
    func testDeleteVaultRemovesFromList() {
        service.createVault(name: "待删")
        let id = firstVault().id

        service.deleteVault(id: id)

        XCTAssertTrue(service.vaults.isEmpty)
    }

    /// 验证 deleteVault 删除选中笔记本时清除 selectedVaultID
    func testDeleteVaultClearsSelectedWhenDeletingSelected() {
        service.createVault(name: "选中待删")
        let vault = firstVault()
        service.selectVault(vault)
        XCTAssertEqual(service.selectedVaultID, vault.id)

        service.deleteVault(id: vault.id)

        XCTAssertNil(service.selectedVaultID)
    }

    /// 验证 deleteVault 删除非选中笔记本时保留 selectedVaultID
    func testDeleteVaultKeepsSelectedWhenDeletingOther() {
        service.createVault(name: "A")
        service.createVault(name: "B")
        let a = service.vaults[0]
        let b = service.vaults[1]
        service.selectVault(a)

        service.deleteVault(id: b.id)

        XCTAssertEqual(service.selectedVaultID, a.id)
        XCTAssertEqual(service.vaults.count, 1)
    }

    /// 验证 deleteVault 不存在的 ID 不崩溃
    func testDeleteVaultNonExistentIDNoCrash() {
        service.deleteVault(id: UUID())
        XCTAssertTrue(service.vaults.isEmpty)
    }
}

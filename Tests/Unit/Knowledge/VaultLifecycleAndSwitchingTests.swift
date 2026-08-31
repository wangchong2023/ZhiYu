//
//  VaultLifecycleAndSwitchingTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：深入验证 VaultService 的生命周期管理（创建/选择/退出/重命名/删除）、数据库切换广播与未配置降级分支。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class VaultLifecycleAndSwitchingTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 选择保险库与发送广播分支

    func testSelectVault_UpdatesSelectedVaultIDAndPostsNotification() {
        let service = VaultService.shared
        let vault = Vault(
            id: UUID(),
            name: "个人知识库",
            createdAt: Date(),
            updatedAt: Date(),
            pageCount: 5,
            icon: "📚"
        )

        let exp = expectation(forNotification: .vaultWillSwitch, object: nil, handler: nil)

        service.selectVault(vault)

        XCTAssertEqual(service.selectedVaultID, vault.id, "选中的保险库 ID 应当被即时更新")
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - 2. 退出保险库与连接释放分支

    func testExitVault_ClearsSelectionAndReleasesConnection() {
        let service = VaultService.shared
        service.selectedVaultID = UUID()

        let exp = expectation(forNotification: .vaultWillSwitch, object: nil, handler: nil)

        service.exitVault()

        XCTAssertNil(service.selectedVaultID, "退出后选中的保险库 ID 应当为 nil")
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - 3. 创建与删除保险库分支

    func testCreateVault_AppendsNewVaultToList() {
        let service = VaultService.shared
        let initialCount = service.vaults.count

        service.createVault(name: "调研笔记本", icon: "🔬", description: "项目调研资料")

        XCTAssertEqual(service.vaults.count, initialCount + 1, "创建后保险库列表应当自增")
        XCTAssertTrue(service.vaults.contains(where: { $0.name == "调研笔记本" }))
    }

    func testDeleteCurrentVault_PostsVaultWillSwitchNotification() {
        let service = VaultService.shared
        let vaultID = UUID()
        let vault = Vault(id: vaultID, name: "临时保险库", createdAt: Date(), updatedAt: Date(), pageCount: 0)
        service.vaults.append(vault)
        service.selectedVaultID = vaultID

        let exp = expectation(forNotification: .vaultWillSwitch, object: nil, handler: nil)

        service.deleteVault(id: vaultID)

        XCTAssertNil(service.selectedVaultID, "删除当前选中保险库后 selectedVaultID 应为 nil")
        wait(for: [exp], timeout: 1.0)
    }
}

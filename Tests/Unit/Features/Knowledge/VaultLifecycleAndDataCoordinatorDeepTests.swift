//
//  VaultLifecycleAndDataCoordinatorDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 VaultService 多保险库生命周期管理、物理路径生成、
//           元数据持久化与退出切换状态机。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class VaultLifecycleAndCoordinatorDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. Vault 物理路径生成测试

    func testVaultService_GetVaultDatabaseURL() {
        let service = VaultService.shared
        let vaultID = UUID()
        let url = service.getVaultDatabaseURL(for: vaultID)

        XCTAssertTrue(url.path.contains("Vaults"))
        XCTAssertTrue(url.path.contains(vaultID.uuidString))
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".sqlite3"))
    }

    // MARK: - 2. 保险库创建、更新与选择状态机测试

    func testVaultService_CreateUpdateAndSelectLifecycle() async {
        let service = VaultService.shared

        // 1. 创建新保险库
        service.createVault(name: "深度学习研究库", icon: "brain.head.profile", description: "关于神经网络的笔记")
        guard let created = service.vaults.first(where: { $0.name == "深度学习研究库" }) else {
            XCTFail("应当成功创建并添加到列表")
            return
        }
        XCTAssertEqual(created.icon, "brain.head.profile")
        XCTAssertEqual(created.description, "关于神经网络的笔记")

        // 2. 选择当前保险库
        service.selectVault(created)
        XCTAssertEqual(service.selectedVaultID, created.id)
        XCTAssertEqual(service.currentVault?.name, "深度学习研究库")

        // 3. 更新保险库配置
        service.updateVault(id: created.id, name: "深度学习前沿库", icon: "sparkles", description: "更新后的描述")
        XCTAssertEqual(service.currentVault?.name, "深度学习前沿库")
        XCTAssertEqual(service.currentVault?.icon, "sparkles")

        // 4. 退出保险库
        service.exitVault()
        XCTAssertNil(service.selectedVaultID)
        XCTAssertNil(service.currentVault)
    }

    // MARK: - 3. 保险库冷启动热恢复与默认演示库测试

    func testVaultService_AutoRestoreAndBuildDemoVaults() {
        let service = VaultService.shared
        let demoVaults = service.buildDefaultDemoVaults()
        XCTAssertEqual(demoVaults.count, 2)

        let fallbackVaults = service.buildFallbackDemoVaults()
        XCTAssertEqual(fallbackVaults.count, 2)

        // 模拟偏好恢复
        guard let first = demoVaults.first else { return }
        service.vaults = demoVaults
        service.keyStore?.set(first.id.uuidString, forKey: AppConstants.Keys.Storage.vaultsSelectedID)

        service.autoRestoreActiveVault()
        XCTAssertEqual(service.selectedVaultID, first.id)
    }
}

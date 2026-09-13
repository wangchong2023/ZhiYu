//
//  VaultDataCoordinatorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 VaultService 数据协调器的演示笔记本构建与 englishName 映射逻辑。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class VaultDataCoordinatorTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        try? await Task.sleep(nanoseconds: 50_000_000)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - buildDefaultDemoVaults

    /// 验证默认演示笔记本包含 2 个内置笔记本
    func testBuildDefaultDemoVaultsReturnsTwoVaults() {
        let vaults = VaultService.shared.buildDefaultDemoVaults()
        XCTAssertEqual(vaults.count, 2, "应返回 2 个内置演示笔记本")
    }

    /// 验证第一个演示笔记本 englishName 为 personalKM
    func testBuildDefaultDemoVaultsFirstVaultEnglishName() {
        let vaults = VaultService.shared.buildDefaultDemoVaults()
        XCTAssertEqual(vaults[0].englishName, BuiltinVaultEnglishName.personalKM,
                       "第一个笔记本 englishName 应为 Personal_KM")
    }

    /// 验证第二个演示笔记本 englishName 为 projectResearch
    func testBuildDefaultDemoVaultsSecondVaultEnglishName() {
        let vaults = VaultService.shared.buildDefaultDemoVaults()
        XCTAssertEqual(vaults[1].englishName, BuiltinVaultEnglishName.projectResearch,
                       "第二个笔记本 englishName 应为 Project_Research")
    }

    /// 验证默认演示笔记本 pageCount 为 0
    func testBuildDefaultDemoVaultsPageCountZero() {
        let vaults = VaultService.shared.buildDefaultDemoVaults()
        XCTAssertTrue(vaults.allSatisfy { $0.pageCount == 0 }, "演示笔记本初始 pageCount 应为 0")
    }

    /// 验证默认演示笔记本 icon 非空
    func testBuildDefaultDemoVaultsIconNonNil() {
        let vaults = VaultService.shared.buildDefaultDemoVaults()
        XCTAssertTrue(vaults.allSatisfy { $0.icon != nil }, "演示笔记本 icon 应非空")
    }

    /// 验证默认演示笔记本 description 非空
    func testBuildDefaultDemoVaultsDescriptionNonEmpty() {
        let vaults = VaultService.shared.buildDefaultDemoVaults()
        XCTAssertTrue(vaults.allSatisfy { !($0.description?.isEmpty ?? true) }, "演示笔记本 description 应非空")
    }

    /// 验证两个演示笔记本 ID 不同
    func testBuildDefaultDemoVaultsDifferentIDs() {
        let vaults = VaultService.shared.buildDefaultDemoVaults()
        XCTAssertNotEqual(vaults[0].id, vaults[1].id, "两个演示笔记本 ID 应不同")
    }

    // MARK: - buildFallbackDemoVaults

    /// 验证降级兜底笔记本包含 2 个
    func testBuildFallbackDemoVaultsReturnsTwoVaults() {
        let vaults = VaultService.shared.buildFallbackDemoVaults()
        XCTAssertEqual(vaults.count, 2, "降级兜底应返回 2 个笔记本")
    }

    /// 验证降级兜底笔记本 englishName 正确映射
    func testBuildFallbackDemoVaultsEnglishNames() {
        let vaults = VaultService.shared.buildFallbackDemoVaults()
        XCTAssertEqual(vaults[0].englishName, BuiltinVaultEnglishName.personalKM)
        XCTAssertEqual(vaults[1].englishName, BuiltinVaultEnglishName.projectResearch)
    }

    /// 验证降级兜底笔记本 pageCount 为 0
    func testBuildFallbackDemoVaultsPageCountZero() {
        let vaults = VaultService.shared.buildFallbackDemoVaults()
        XCTAssertTrue(vaults.allSatisfy { $0.pageCount == 0 }, "降级兜底笔记本 pageCount 应为 0")
    }

    // MARK: - englishName 映射（通过 buildDefaultDemoVaults 间接验证）

    /// 验证默认笔记本 name 映射到 personalKM englishName
    func testDefaultVaultNameMapsToPersonalKM() {
        let vaults = VaultService.shared.buildDefaultDemoVaults()
        // buildDefaultDemoVaults 使用 L10n.Vault.defaultName 作为 name
        // englishName 应映射回 personalKM
        XCTAssertEqual(vaults[0].englishName, BuiltinVaultEnglishName.personalKM)
    }

    /// 验证调研笔记本 name 映射到 projectResearch englishName
    func testResearchVaultNameMapsToProjectResearch() {
        let vaults = VaultService.shared.buildDefaultDemoVaults()
        XCTAssertEqual(vaults[1].englishName, BuiltinVaultEnglishName.projectResearch)
    }
}

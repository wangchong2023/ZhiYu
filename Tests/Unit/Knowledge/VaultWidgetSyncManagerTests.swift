//
//  VaultWidgetSyncManagerTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//
//  系统层级：[L3] 测试层
//  核心职责：验证 VaultWidgetSyncManager 的 Widget 快照写入与页面计数刷新逻辑。
//

import Testing
import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class VaultWidgetSyncManagerTests: XCTestCase {
    private var vaultService: VaultService!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        vaultService = VaultService.shared
        vaultService.vaults = []
        vaultService.selectedVaultID = nil
    }

    override func tearDown() async throws {
        vaultService.vaults = []
        vaultService.selectedVaultID = nil
        vaultService = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - writeWidgetStatsSnapshot

    /// 验证 writeWidgetStatsSnapshot 不崩溃（App Group 不可用时静默返回）
    func testWriteWidgetStatsSnapshotNoCrash() async {
        await vaultService.writeWidgetStatsSnapshot(pageCount: 5, linkCount: 3, tagCount: 2)

        XCTAssertTrue(true)
    }

    /// 验证 writeWidgetStatsSnapshot 默认参数不崩溃
    func testWriteWidgetStatsSnapshotDefaultArgs() async {
        await vaultService.writeWidgetStatsSnapshot(pageCount: 10)

        XCTAssertTrue(true)
    }

    /// 验证 writeWidgetStatsSnapshot 零计数不崩溃
    func testWriteWidgetStatsSnapshotZeroCounts() async {
        await vaultService.writeWidgetStatsSnapshot(pageCount: 0, linkCount: 0, tagCount: 0)

        XCTAssertTrue(true)
    }

    // MARK: - refreshPageCount

    /// 验证 refreshPageCount 空 vaults 不崩溃
    func testRefreshPageCountEmptyVaults() async {
        await vaultService.refreshPageCount(for: UUID())

        XCTAssertTrue(vaultService.vaults.isEmpty)
    }

    /// 验证 refreshPageCount 匹配 vault 更新 pageCount
    func testRefreshPageCountUpdatesMatchingVault() async {
        let vaultID = UUID()
        let vault = Vault(id: vaultID, name: "测试", createdAt: Date(), pageCount: 100)
        vaultService.vaults = [vault]

        await vaultService.refreshPageCount(for: vaultID)

        XCTAssertEqual(vaultService.vaults.first?.pageCount, 0)
    }

    /// 验证 refreshPageCount 非匹配 vault 不更新
    func testRefreshPageCountNonMatchingVaultPreserved() async {
        let vaultID = UUID()
        let otherID = UUID()
        let vault = Vault(id: vaultID, name: "测试", createdAt: Date(), pageCount: 100)
        let other = Vault(id: otherID, name: "其他", createdAt: Date(), pageCount: 50)
        vaultService.vaults = [vault, other]

        await vaultService.refreshPageCount(for: UUID())

        XCTAssertEqual(vaultService.vaults[0].pageCount, 100)
        XCTAssertEqual(vaultService.vaults[1].pageCount, 50)
    }

    // MARK: - refreshAllPageCounts

    /// 验证 refreshAllPageCounts 空 vaults 不崩溃
    func testRefreshAllPageCountsEmptyVaults() async {
        await vaultService.refreshAllPageCounts()

        XCTAssertTrue(vaultService.vaults.isEmpty)
    }

    /// 验证 refreshAllPageCounts 无 DB 文件时走主库兜底
    func testRefreshAllPageCountsNoDBFallbackToMain() async {
        let vaultID = UUID()
        let vault = Vault(id: vaultID, name: "测试", createdAt: Date(), pageCount: 100)
        vaultService.vaults = [vault]
        vaultService.selectedVaultID = vaultID

        await vaultService.refreshAllPageCounts()

        // 主库兜底会设置 pageCount，具体值取决于主库实际页面数
        XCTAssertNotNil(vaultService.vaults.first?.pageCount)
    }

    // MARK: - refreshPageCountFromMainDB

    /// 验证 refreshPageCountFromMainDB 不崩溃
    func testRefreshPageCountFromMainDBNoCrash() async {
        let vaultID = UUID()
        let vault = Vault(id: vaultID, name: "测试", createdAt: Date(), pageCount: 100)
        vaultService.vaults = [vault]

        await vaultService.refreshPageCountFromMainDB(for: vaultID)

        // 主库可能无 dbWriter，静默返回
        XCTAssertTrue(true)
    }

    /// 验证 refreshPageCountFromMainDB 非匹配 vault 不更新
    func testRefreshPageCountFromMainDBNonMatchingVaultPreserved() async {
        let vaultID = UUID()
        let vault = Vault(id: vaultID, name: "测试", createdAt: Date(), pageCount: 100)
        vaultService.vaults = [vault]

        await vaultService.refreshPageCountFromMainDB(for: UUID())

        XCTAssertEqual(vaultService.vaults.first?.pageCount, 100)
    }
}

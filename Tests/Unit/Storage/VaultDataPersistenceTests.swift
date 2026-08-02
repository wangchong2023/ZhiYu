//
//  VaultDataPersistenceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证多笔记本切换后数据不丢失的完整链路

import XCTest
import UFPStorage
@testable import ZhiYu

@MainActor
final class VaultDataPersistenceTests: XCTestCase {

    private var vaultAID: UUID!
    private var vaultBID: UUID!
    private var dbADirectory: URL!
    private var dbBDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        await setupFullMockEnvironment()

        vaultAID = UUID()
        vaultBID = UUID()

        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        dbADirectory = appSupport
            .appendingPathComponent("Vaults")
            .appendingPathComponent(vaultAID.uuidString)
        dbBDirectory = appSupport
            .appendingPathComponent("Vaults")
            .appendingPathComponent(vaultBID.uuidString)
        try FileManager.default.createDirectory(at: dbADirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dbBDirectory, withIntermediateDirectories: true)

        let dbAURL = dbADirectory.appendingPathComponent("vault.sqlite3")
        let dbBURL = dbBDirectory.appendingPathComponent("vault.sqlite3")

        let poolA = try DatabasePool(path: dbAURL.path)
        let poolB = try DatabasePool(path: dbBURL.path)
        let migrator = DatabaseManager.shared.migrator
        try migrator.migrate(poolA)
        try migrator.migrate(poolB)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dbADirectory)
        try? FileManager.default.removeItem(at: dbBDirectory)
        vaultAID = nil
        vaultBID = nil
        dbADirectory = nil
        dbBDirectory = nil
        try await super.tearDown()
    }

    // MARK: - 核心场景：注入 → 切走 → 切回 → 数据仍在

    func testInitialNotebooksPersistAfterSwitchingVaults() async throws {
        let pageStore: any AnyPageStore = ServiceContainer.shared.resolve(SQLiteStore.self)
        let dbAURL = dbADirectory.appendingPathComponent("vault.sqlite3")
        let dbBURL = dbBDirectory.appendingPathComponent("vault.sqlite3")

        // 写入数据到 Vault A
        try await DatabaseManager.shared.switchDatabase(to: vaultAID, at: dbAURL)
        _ = try await InitialNotebookGenerator.generate(in: pageStore)
        let countABeforeSwitch = try await pageStore.fetchAllPages().count
        XCTAssertGreaterThan(countABeforeSwitch, 0, "Vault A 应该有数据")

        // 切到 Vault B 写入数据
        try await DatabaseManager.shared.switchDatabase(to: vaultBID, at: dbBURL)
        _ = try await InitialNotebookGenerator.generate(in: pageStore)
        let countBBeforeSwitch = try await pageStore.fetchAllPages().count
        XCTAssertGreaterThan(countBBeforeSwitch, 0, "Vault B 应该有数据")

        // 切回 Vault A — 数据量不应该减少
        try await DatabaseManager.shared.switchDatabase(to: vaultAID, at: dbAURL)
        let countAAfterSwitch = try await pageStore.fetchAllPages().count
        XCTAssertGreaterThanOrEqual(countAAfterSwitch, countABeforeSwitch,
            "切回 Vault A 后数据不能减少（允许 seed 追加）")

        // 再切回 Vault B — 数据同样不应该减少
        try await DatabaseManager.shared.switchDatabase(to: vaultBID, at: dbBURL)
        let countBAfterSwitch = try await pageStore.fetchAllPages().count
        XCTAssertGreaterThanOrEqual(countBAfterSwitch, countBBeforeSwitch,
            "切回 Vault B 后数据不能减少")
    }

    // MARK: - switchDatabase 本身不会清除数据

    func testSwitchDatabaseDoesNotEraseData() async throws {
        let dbURL = dbADirectory.appendingPathComponent("vault.sqlite3")
        try await DatabaseManager.shared.switchDatabase(to: vaultAID, at: dbURL)

        let pageStore: any AnyPageStore = ServiceContainer.shared.resolve(SQLiteStore.self)
        _ = try await InitialNotebookGenerator.generate(in: pageStore)
        let baselineCount = try await pageStore.fetchAllPages().count
        XCTAssertGreaterThan(baselineCount, 0, "基线数据应存在")

        for i in 1...3 {
            let tempDir = dbADirectory.deletingLastPathComponent().appendingPathComponent("temp_\(i)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let tempURL = tempDir.appendingPathComponent("vault.sqlite3")
            let tempPool = try DatabasePool(path: tempURL.path)
            try DatabaseManager.shared.migrator.migrate(tempPool)

            try await DatabaseManager.shared.switchDatabase(to: UUID(), at: tempURL)
            try await DatabaseManager.shared.switchDatabase(to: vaultAID, at: dbURL)

            let pages = try await pageStore.fetchAllPages()
            XCTAssertGreaterThanOrEqual(pages.count, baselineCount,
                "第 \(i) 次切回后数据不能减少")
        }
    }
}

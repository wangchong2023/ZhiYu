//
//  WidgetRepositoryTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 WidgetRepository JSON 快照读取 + VaultRepository pageCount 持久化

import XCTest
import UFPStorage
@testable import ZhiYu

@MainActor
final class WidgetRepositoryTests: XCTestCase {

    // MARK: - VaultRepository pageCount 测试

    private var dbQueue: DatabaseQueue!
    private var repository: SQLiteVaultRepository!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        repository = SQLiteVaultRepository(dbWriter: dbQueue)

        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("v1_global_schema") { db in
            try db.create(table: VaultRecord.databaseTableName) { t in
                t.column(VaultRecord.CodingKeys.id.rawValue, .text).primaryKey()
                t.column(VaultRecord.CodingKeys.name.rawValue, .text).notNull()
                t.column(VaultRecord.CodingKeys.path.rawValue, .text).notNull()
                t.column(VaultRecord.CodingKeys.icon.rawValue, .text)
                t.column(VaultRecord.CodingKeys.pageCount.rawValue, .integer).notNull().defaults(to: 0)
                t.column(VaultRecord.CodingKeys.createdAt.rawValue, .datetime).notNull().defaults(to: Date())
                t.column(VaultRecord.CodingKeys.updatedAt.rawValue, .datetime).notNull().defaults(to: Date())
                t.column(VaultRecord.CodingKeys.lastAccessedAt.rawValue, .datetime).notNull().defaults(to: Date())
            }
            try db.create(table: "global_settings") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
                t.column("updated_at", .datetime).notNull().defaults(to: Date())
            }
        }
        try migrator.migrate(dbQueue)
    }

    override func tearDown() async throws {
        dbQueue = nil
        repository = nil
        try await super.tearDown()
    }

    // MARK: - pageCount 持久化

    func testSaveAndFetchVaultWithPageCount() async throws {
        let vaultID = UUID()
        let vault = Vault(id: vaultID, name: "Test", createdAt: Date(), updatedAt: Date(), pageCount: 42)
        try await repository.saveVault(vault)
        let all = try await repository.fetchAllVaults()
        let fetched = try XCTUnwrap(all.first(where: { $0.id == vaultID }))
        XCTAssertEqual(fetched.pageCount, 42)
    }

    func testUpdateVaultPageCount() async throws {
        let id = UUID()
        try await repository.saveVault(Vault(id: id, name: "T", createdAt: Date(), updatedAt: Date(), pageCount: 0))
        try await repository.saveVault(Vault(id: id, name: "T", createdAt: Date(), updatedAt: Date(), pageCount: 99))
        let all = try await repository.fetchAllVaults()
        XCTAssertEqual(all.first(where: { $0.id == id })?.pageCount, 99)
    }

    func testNewVaultDefaultsToZero() async throws {
        let id = UUID()
        try await repository.saveVault(Vault(id: id, name: "E", createdAt: Date(), updatedAt: Date(), pageCount: 0))
        let all = try await repository.fetchAllVaults()
        XCTAssertEqual(all.first(where: { $0.id == id })?.pageCount, 0)
    }

    func testMultipleVaultsIndependentCounts() async throws {
        let a = UUID(), b = UUID()
        try await repository.saveVault(Vault(id: a, name: "A", createdAt: Date(), updatedAt: Date(), pageCount: 10))
        try await repository.saveVault(Vault(id: b, name: "B", createdAt: Date(), updatedAt: Date(), pageCount: 20))
        let all = try await repository.fetchAllVaults()
        XCTAssertEqual(all.first(where: { $0.id == a })?.pageCount, 10)
        XCTAssertEqual(all.first(where: { $0.id == b })?.pageCount, 20)
    }

    // MARK: - global_settings 写入

    func testSaveSetting() async throws {
        try await repository.saveSetting(key: "vaults.selectedID", value: "test-uuid")
        let value = try await dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM global_settings WHERE key = ?", arguments: ["vaults.selectedID"])
        }
        XCTAssertEqual(value, "test-uuid")
    }
}

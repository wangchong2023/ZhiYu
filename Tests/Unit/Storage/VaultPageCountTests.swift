//
//  VaultPageCountTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 VaultRepository 对 pageCount 字段的完整读写链路

import XCTest
import UFPStorage
@testable import ZhiYu

@MainActor
final class VaultPageCountTests: XCTestCase {

    private var dbQueue: DatabaseQueue!
    private var repository: SQLiteVaultRepository!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        repository = SQLiteVaultRepository(dbWriter: dbQueue)

        // 跑全局迁移，建立 global_vaults 表（含 page_count 列）
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
        }
        try migrator.migrate(dbQueue)
    }

    override func tearDown() async throws {
        dbQueue = nil
        repository = nil
        try await super.tearDown()
    }

    // MARK: - 正向路径: 写 pageCount → 读 pageCount

    /// 验证 saveVault 持久化 pageCount 后 fetchAllVaults 能正确读取
    func testSaveAndFetchVaultWithPageCount() async throws {
        // Arrange: 创建一个带 pageCount 的 vault
        let vaultID = UUID()
        let vault = Vault(
            id: vaultID,
            name: "测试笔记本",
            createdAt: Date(),
            updatedAt: Date(),
            pageCount: 42,
            icon: "📚",
            description: "测试描述"
        )
        try await repository.saveVault(vault)

        // Act: 读取全部 vault
        let allVaults = try await repository.fetchAllVaults()

        // Assert: 找到刚保存的 vault 且 pageCount = 42
        let fetched = try XCTUnwrap(allVaults.first(where: { $0.id == vaultID }))
        XCTAssertEqual(fetched.pageCount, 42)
        XCTAssertEqual(fetched.name, "测试笔记本")
        XCTAssertEqual(fetched.icon, "📚")
    }

    // MARK: - 更新路径: 修改 pageCount 后重新读取

    /// 验证可以先 save(pageCount=0) 再 save(pageCount=99) 读取到最新值
    func testUpdateVaultPageCount() async throws {
        let vaultID = UUID()

        // 第一次: pageCount = 0
        let vault0 = Vault(id: vaultID, name: "T", createdAt: Date(), updatedAt: Date(), pageCount: 0)
        try await repository.saveVault(vault0)

        // 第二次: pageCount = 99
        let vault99 = Vault(id: vaultID, name: "T", createdAt: Date(), updatedAt: Date(), pageCount: 99)
        try await repository.saveVault(vault99)

        let allVaults = try await repository.fetchAllVaults()
        let fetched = try XCTUnwrap(allVaults.first(where: { $0.id == vaultID }))
        XCTAssertEqual(fetched.pageCount, 99)
    }

    // MARK: - 冷启动路径: 新创建的 vault pageCount 默认为 0

    func testNewVaultDefaultsToZeroPageCount() async throws {
        let vaultID = UUID()
        let vault = Vault(id: vaultID, name: "空笔记本", createdAt: Date(), updatedAt: Date(), pageCount: 0)
        try await repository.saveVault(vault)

        let allVaults = try await repository.fetchAllVaults()
        let fetched = try XCTUnwrap(allVaults.first(where: { $0.id == vaultID }))
        XCTAssertEqual(fetched.pageCount, 0)
    }

    // MARK: - 多 Vault 各自独立 pageCount

    func testMultipleVaultsHaveIndependentPageCounts() async throws {
        let idA = UUID()
        let idB = UUID()

        try await repository.saveVault(Vault(id: idA, name: "A", createdAt: Date(), updatedAt: Date(), pageCount: 10))
        try await repository.saveVault(Vault(id: idB, name: "B", createdAt: Date(), updatedAt: Date(), pageCount: 20))

        let allVaults = try await repository.fetchAllVaults()
        XCTAssertEqual(allVaults.first(where: { $0.id == idA })?.pageCount, 10)
        XCTAssertEqual(allVaults.first(where: { $0.id == idB })?.pageCount, 20)
    }
}

//
//  GenericSchemaMigratorTests.swift
//  UFPStorageTests
//
//  系统层级：[UFPStorageTests]
//  核心职责：验证 GenericSchemaMigrator 的注册/执行/幂等/增量迁移行为。
//

import XCTest
import GRDB
@testable import UFPStorage

final class GenericSchemaMigratorTests: XCTestCase {

    private var migrator: GenericSchemaMigrator!

    override func setUp() async throws {
        try await super.setUp()
        migrator = GenericSchemaMigrator()
    }

    override func tearDown() async throws {
        migrator = nil
        try await super.tearDown()
    }

    // MARK: - 基础执行

    func testMigrate_ExecutesRegisteredMigrations() throws {
        // Given
        migrator.registerMigration("create_users") { db in
            try db.create(table: "users") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
        }

        // When
        let dbQueue = try DatabaseQueue()
        try migrator.migrate(dbQueue)

        // Then — 表已创建
        let tableNames = try dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
        }
        XCTAssertTrue(tableNames.contains("users"), "迁移后应创建 users 表")
    }

    // MARK: - 幂等性

    func testHasCompletedMigrations_AfterMigrate_IsTrue() throws {
        // Given
        migrator.registerMigration("v1") { db in
            try db.create(table: "v1_table") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }

        // When
        let dbQueue = try DatabaseQueue()
        try migrator.migrate(dbQueue)
        let completed = try migrator.hasCompletedMigrations(dbQueue)

        // Then
        XCTAssertTrue(completed, "执行全部迁移后 hasCompletedMigrations 应为 true")
    }

    func testHasCompletedMigrations_BeforeMigrate_IsFalse() throws {
        // Given
        migrator.registerMigration("v1") { db in
            try db.create(table: "v1_table") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }

        // When — 未执行迁移
        let dbQueue = try DatabaseQueue()
        let completed = try migrator.hasCompletedMigrations(dbQueue)

        // Then
        XCTAssertFalse(completed, "未执行迁移时 hasCompletedMigrations 应为 false")
    }

    // MARK: - 增量迁移

    func testMigrate_WithMultipleMigrations_AppliesInOrder() throws {
        // Given
        migrator.registerMigration("v1") { db in
            try db.create(table: "t1") { t in t.autoIncrementedPrimaryKey("id") }
        }
        migrator.registerMigration("v2") { db in
            try db.alter(table: "t1") { t in
                t.add(column: "name", .text)
            }
        }

        // When
        let dbQueue = try DatabaseQueue()
        try migrator.migrate(dbQueue)

        // Then — v2 的列已追加
        let columns = try dbQueue.read { db in
            try db.columns(in: "t1").map(\.name)
        }
        XCTAssertTrue(columns.contains("name"), "增量迁移 v2 应追加 name 列")
    }

    // MARK: - 迁移执行器可复用

    func testSameMigrator_OnFreshDatabase_AppliesCleanly() throws {
        // Given
        migrator.registerMigration("base") { db in
            try db.create(table: "base_table") { t in t.autoIncrementedPrimaryKey("id") }
        }

        // When — 同一迁移器作用于两个全新数据库
        let db1 = try DatabaseQueue()
        let db2 = try DatabaseQueue()
        try migrator.migrate(db1)
        try migrator.migrate(db2)

        // Then — 两库均完成迁移
        let completed1 = try migrator.hasCompletedMigrations(db1)
        let completed2 = try migrator.hasCompletedMigrations(db2)
        XCTAssertTrue(completed1, "第一个库应完成迁移")
        XCTAssertTrue(completed2, "第二个库应完成迁移")
    }
}

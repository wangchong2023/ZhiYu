//
//  GenericDatabaseManagerTests.swift
//  UFPStorageTests
//
//  系统层级：[UFPStorageTests]
//  核心职责：验证 GenericDatabaseManager 纯物理引擎（reset 排空、建库连接、降级骨架）。
//           迁移自 ZhiYuTests 的 DatabaseManagerLifecycleTests / DatabaseManagerDegradationTests
//           物理引擎用例（reset / 建库 / 降级状态）。
//

import XCTest
import GRDB
@testable import UFPStorage

final class GenericDatabaseManagerTests: XCTestCase {

    private var engine: GenericDatabaseManager!
    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GenericDatabaseManagerTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        engine = GenericDatabaseManager()
        engine.vaultMigrator = makeTestMigrator()
        engine.globalMigrator = makeTestMigrator()
    }

    override func tearDown() async throws {
        engine.reset()
        engine = nil
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        try await super.tearDown()
    }

    /// 构造一个不含业务 schema 的通用迁移器。
    private func makeTestMigrator() -> GenericSchemaMigrator {
        let migrator = GenericSchemaMigrator()
        migrator.registerMigration("test_schema") { db in
            try db.create(table: "test_items") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
            }
        }
        return migrator
    }

    // MARK: - reset 后属性验证

    func testResetAfterDbWriterIsNil() {
        XCTAssertNil(engine.dbWriter, "reset 后 dbWriter 应为 nil")
    }

    func testResetAfterGlobalWriterIsNil() {
        XCTAssertNil(engine.globalWriter, "reset 后 globalWriter 应为 nil")
    }

    func testResetClearsAllWriters() {
        let memoryQueue = try? DatabaseQueue()
        engine.dbWriter = memoryQueue
        XCTAssertNotNil(engine.dbWriter)

        engine.reset()
        XCTAssertNil(engine.dbWriter, "reset 后 dbWriter 应为 nil")
        XCTAssertNil(engine.globalWriter, "reset 后 globalWriter 应为 nil")
        XCTAssertEqual(engine.state, .uninitialized, "reset 后 state 应为 uninitialized")
    }

    // MARK: - 正常 setup 状态测试

    func testNormalSetupStateIsReady() throws {
        let validPath = tempDir.appendingPathComponent("valid_vault.sqlite3")
        try engine.setup(at: validPath, globalDatabaseName: "global.sqlite3")

        XCTAssertEqual(engine.state, .ready, "正常 setup 后 state 应为 .ready")
        XCTAssertNotNil(engine.dbWriter)
        XCTAssertNotNil(engine.dbURL)
        XCTAssertNotNil(engine.globalWriter)
        XCTAssertNotNil(engine.globalDBURL)
    }

    // MARK: - 降级状态一致性测试

    /// 验证 setup 失败后降级到内存模式时，dbWriter 已挂载内存库、dbURL 为 nil。
    func testStateAfterDegradationToInMemory() {
        let invalidPath = "/dev/null/cannot_create_db/vault.sqlite3"

        do {
            try engine.setup(at: URL(fileURLWithPath: invalidPath), globalDatabaseName: "global.sqlite3")
            XCTFail("setup 应抛出异常")
        } catch {
            // 预期抛出异常
        }

        let state = engine.state
        XCTAssertNotNil(engine.dbWriter, "降级后 dbWriter 应为内存数据库，不应为 nil")
        if case .corrupted = state {
            XCTFail("降级到内存模式成功后 state 仍为 .corrupted，但 dbWriter 非 nil。" +
                    "状态不一致：UI 会显示损坏警告但实际内存数据库已正常工作。")
        }
    }

    /// 验证降级到内存模式后，数据为临时的（dbURL 为 nil）。
    func testDegradedDataIsInMemory() {
        let invalidPath = "/dev/null/cannot_create_db/vault.sqlite3"

        do {
            try engine.setup(at: URL(fileURLWithPath: invalidPath), globalDatabaseName: "global.sqlite3")
            XCTFail("setup 应抛出异常")
        } catch {
            // 预期抛出异常
        }

        XCTAssertNil(engine.dbURL, "降级到内存模式后 dbURL 应为 nil")
        XCTAssertNotNil(engine.dbWriter, "降级后应有内存数据库连接")
    }

    // MARK: - 重复 setup 测试

    /// 验证先失败再成功 setup 的状态恢复。
    func testRecoveryAfterFailedSetup() throws {
        let invalidPath = "/dev/null/cannot_create_db/vault.sqlite3"
        do {
            try engine.setup(at: URL(fileURLWithPath: invalidPath), globalDatabaseName: "global.sqlite3")
            XCTFail("setup 应抛出异常")
        } catch {
            // 预期失败
        }

        engine.reset()
        let validPath = tempDir.appendingPathComponent("recovery_vault.sqlite3")
        try engine.setup(at: validPath, globalDatabaseName: "global.sqlite3")

        XCTAssertEqual(engine.state, .ready, "重置后成功 setup，state 应恢复为 .ready")
    }
}
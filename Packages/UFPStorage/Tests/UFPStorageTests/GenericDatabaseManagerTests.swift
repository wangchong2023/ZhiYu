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

/// 线程安全可变容器，用于在 @Sendable 闭包中收集回调结果。
private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

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

    // MARK: - setupForTesting

    /// 验证 setupForTesting 为内存库注入 dbWriter/globalWriter 并完成迁移。
    func testSetupForTesting_WithInMemoryQueue_IsReady() throws {
        // Given — 独立内存连接
        let dbQueue = try DatabaseQueue()

        // When
        try engine.setupInMemory(with: dbQueue)

        // Then — 专属与全局库均已挂载
        XCTAssertNotNil(engine.dbWriter, "setupForTesting 应挂载专属库连接")
        XCTAssertNotNil(engine.globalWriter, "setupForTesting 应挂载全局库连接")
        XCTAssertTrue(engine.usesTransientStorage, "setupForTesting 应标记 usesTransientStorage")
        // 通过迁移器创建的 test_items 表应可用
        let count = try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM test_items") ?? 0
        }
        XCTAssertEqual(count, 0, "迁移后 test_items 表应存在且为空")
    }

    // MARK: - migrate

    /// 验证 migrate 对目标连接执行专属迁移。
    func testMigrate_OnFreshQueue_CreatesSchema() throws {
        // Given
        let dbQueue = try DatabaseQueue()

        // When
        try engine.migrate(dbQueue)

        // Then
        let tableNames = try dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
        }
        XCTAssertTrue(tableNames.contains("test_items"), "migrate 应创建 test_items 表")
    }

    // MARK: - releaseDatabaseConnection

    /// 验证 releaseDatabaseConnection 确定性关闭 dbWriter。
    func testReleaseDatabaseConnection_AfterSetup_ClosesWriter() throws {
        // Given
        let validPath = tempDir.appendingPathComponent("release_vault.sqlite3")
        try engine.setup(at: validPath, globalDatabaseName: "global.sqlite3")
        XCTAssertNotNil(engine.dbWriter)

        // When
        engine.releaseDatabaseConnection()

        // Then
        XCTAssertNil(engine.dbWriter, "releaseDatabaseConnection 后 dbWriter 应为 nil")
    }

    // MARK: - switchDatabase 热切换

    /// 验证 switchDatabase 切换新库并广播回调、触发完整性校验与签名更新。
    func testSwitchDatabase_WithNewVault_RemountsAndNotifies() async throws {
        // Given — 注入完整校验与签名闭包，并记录回调
        engine.integrityVerifier = { _ in true }
        let signatureUpdatedURLs = Box<[URL]>([])
        engine.signatureUpdater = { url in
            signatureUpdatedURLs.value.append(url)
        }
        let didSwitch = Box<(UUID, URL)?>(nil)
        engine.onDatabaseDidSwitch = { id, url in
            didSwitch.value = (id, url)
        }

        let firstPath = tempDir.appendingPathComponent("switch_vault_a.sqlite3")
        try engine.setup(at: firstPath, globalDatabaseName: "global.sqlite3")

        // When — 切换到新库
        let vaultID = UUID()
        let secondPath = tempDir.appendingPathComponent("switch_vault_b.sqlite3")
        try await engine.switchDatabase(to: vaultID, at: secondPath)

        // Then — dbURL 指向新库，回调已触发，签名对旧库与新库各更新一次
        XCTAssertEqual(engine.dbURL?.path, secondPath.path, "switch 后 dbURL 应指向新库")
        XCTAssertNotNil(engine.dbWriter, "switch 后应挂载新库连接")
        XCTAssertEqual(engine.state, .ready, "switch 后 state 应为 ready")
        XCTAssertEqual(didSwitch.value?.0, vaultID, "切换回调应携带目标 vaultID")
        XCTAssertEqual(didSwitch.value?.1.path, secondPath.path, "切换回调应携带目标 URL")
        XCTAssertTrue(signatureUpdatedURLs.value.contains(where: { $0.path == firstPath.path }),
                      "关闭旧库后应更新旧库签名")
        XCTAssertTrue(signatureUpdatedURLs.value.contains(where: { $0.path == secondPath.path }),
                      "切换成功后应更新新库签名")
    }

    /// 验证 switchDatabase 在目标库完整性校验失败时仍继续切换（容错）。
    func testSwitchDatabase_WhenIntegrityFails_StillRemounts() async throws {
        // Given — 校验失败
        engine.integrityVerifier = { _ in false }
        let firstPath = tempDir.appendingPathComponent("switch_fail_a.sqlite3")
        try engine.setup(at: firstPath, globalDatabaseName: "global.sqlite3")

        // When
        let secondPath = tempDir.appendingPathComponent("switch_fail_b.sqlite3")
        try await engine.switchDatabase(to: UUID(), at: secondPath)

        // Then — 校验失败不应阻断切换
        XCTAssertEqual(engine.dbURL?.path, secondPath.path, "校验失败后仍应切换到新库")
        XCTAssertNotNil(engine.dbWriter)
    }

    /// 验证 switchDatabase 的事务排空超时时仍强制关闭并切换。
    func testSwitchDatabase_WhenDrainTimesOut_ForcesClose() async throws {
        // Given — 排空返回 false（超时）
        engine.drainTransactions = { false }
        let firstPath = tempDir.appendingPathComponent("switch_drain_a.sqlite3")
        try engine.setup(at: firstPath, globalDatabaseName: "global.sqlite3")

        // When
        let secondPath = tempDir.appendingPathComponent("switch_drain_b.sqlite3")
        try await engine.switchDatabase(to: UUID(), at: secondPath)

        // Then — 排空超时后仍强制切换
        XCTAssertEqual(engine.dbURL?.path, secondPath.path, "排空超时后应强制切换到新库")
        XCTAssertNotNil(engine.dbWriter)
    }

    // MARK: - 缺陷导向：switchDatabase 建库/迁移失败时的状态一致性

    /// 缺陷验证：`switchDatabase` 中新库创建/迁移抛错时，旧连接已关闭、`dbURL` 已指向
    /// 新库但 `dbWriter` 仍为 nil，留下半开不一致状态且无降级、无回滚。
    /// 修复后失败路径应降级到内存库（dbWriter 非 nil、dbURL 为 nil），与 `setup` 一致。
    func testSwitchDatabase_WhenCreateMigrateFails_DegradesToInMemoryConsistently() async throws {
        // Given — 先正常 setup 到一个合法路径
        let firstPath = tempDir.appendingPathComponent("switch_failcreate_a.sqlite3")
        try engine.setup(at: firstPath, globalDatabaseName: "global.sqlite3")
        XCTAssertNotNil(engine.dbWriter)

        // When — 切到必然创建失败的非法路径（触发 createAndMigrateDatabase 抛错）
        let invalidPath = "/dev/null/cannot_create_db/switch_vault.sqlite3"
        do {
            try await engine.switchDatabase(to: UUID(), at: URL(fileURLWithPath: invalidPath))
            XCTFail("切到非法路径应抛出异常")
        } catch {
            // 预期抛出异常
        }

        // Then — 失败后应降级到内存库，状态一致：dbWriter 非 nil、dbURL 为 nil
        XCTAssertNotNil(engine.dbWriter,
            "切换失败后应降级到内存库，dbWriter 不应为 nil（缺陷：半开状态 dbWriter 为 nil）")
        XCTAssertNil(engine.dbURL,
            "切换失败降级后 dbURL 应为 nil（不应残留指向失败新库的半开状态）")
    }

    // MARK: - 注入闭包覆盖

    /// 验证 setup 在有存量文件时会触发完整性校验异步闭包。
    func testSetup_WithExistingFile_TriggersIntegrityCheck() async throws {
        // Given — 先建一个物理库，使其文件存在；注入完整性校验处理器记录调用
        let path = tempDir.appendingPathComponent("integrity_vault.sqlite3")
        try engine.setup(at: path, globalDatabaseName: "global.sqlite3")
        engine.reset()

        var integrityCalls = 0
        let freshEngine = GenericDatabaseManager()
        freshEngine.vaultMigrator = makeTestMigrator()
        freshEngine.globalMigrator = makeTestMigrator()
        freshEngine.integrityCheckHandler = { _ in integrityCalls += 1 }

        // When — 对已存在文件再 setup
        try freshEngine.setup(at: path, globalDatabaseName: "global.sqlite3")

        // Then — 异步校验被触发
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertGreaterThanOrEqual(integrityCalls, 1, "存在文件时应触发完整性校验")
    }
}
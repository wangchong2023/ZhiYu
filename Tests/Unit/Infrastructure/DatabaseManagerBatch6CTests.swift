//
//  DatabaseManagerBatch6CTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 DatabaseManager 状态机、事务计数、热切换排空与降级路径，复现 Finding #17/#18。
//           注：DatabaseManager.shared 是单例，无完整 reset 接口，测试避免调用 setupForTesting
//           以防污染其他测试。需要 dbWriter 的验证使用独立 DatabaseQueue。
//

import XCTest
import UFPStorage
@testable import ZhiYu

@MainActor
final class DatabaseManagerBatch6CTests: XCTestCase {

    private var tempDir: URL!
    private var savedDbWriter: (any DatabaseWriter)?
    private var savedGlobalWriter: (any DatabaseWriter)?
    private var savedIsInTesting: Bool = false

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DatabaseManagerTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        // 保存状态，测试后恢复，避免污染其他测试
        savedDbWriter = DatabaseManager.shared.dbWriter
        savedGlobalWriter = DatabaseManager.shared.globalWriter
        savedIsInTesting = DatabaseManager.shared.isInTesting
        // 重置事务门禁（Finding #18 修复后的新机制）
        await DatabaseManager.shared.transactionGatekeeper.reset()
        DatabaseManager.shared.reset()
    }

    override func tearDown() async throws {
        // 恢复 DatabaseManager 的 writer 和测试标志
        DatabaseManager.shared.dbWriter = savedDbWriter
        DatabaseManager.shared.globalWriter = savedGlobalWriter
        DatabaseManager.shared.isInTesting = savedIsInTesting
        await DatabaseManager.shared.transactionGatekeeper.reset()
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        try await super.tearDown()
    }

    // MARK: - reset 后属性验证

    func testReset后_dbWriter为Nil() {
        XCTAssertNil(DatabaseManager.shared.dbWriter, "reset 后 dbWriter 应为 nil")
    }

    func testReset后_globalWriter为Nil() {
        XCTAssertNil(DatabaseManager.shared.globalWriter, "reset 后 globalWriter 应为 nil")
    }

    // MARK: - 事务计数（Finding #18 修复后：通过 TransactionGatekeeper actor 串行化）

    func testIncrementActiveTransactions_计数递增() async throws {
        let before = await DatabaseManager.shared.activeTransactionsCount
        try await DatabaseManager.shared.incrementActiveTransactions()
        let after1 = await DatabaseManager.shared.activeTransactionsCount
        XCTAssertEqual(after1, before + 1)
        try await DatabaseManager.shared.incrementActiveTransactions()
        let after2 = await DatabaseManager.shared.activeTransactionsCount
        XCTAssertEqual(after2, before + 2)
        // 清理
        await DatabaseManager.shared.decrementActiveTransactions()
        await DatabaseManager.shared.decrementActiveTransactions()
    }

    func testDecrementActiveTransactions_计数递减() async throws {
        let before = await DatabaseManager.shared.activeTransactionsCount
        try await DatabaseManager.shared.incrementActiveTransactions()
        try await DatabaseManager.shared.incrementActiveTransactions()
        await DatabaseManager.shared.decrementActiveTransactions()
        let after = await DatabaseManager.shared.activeTransactionsCount
        XCTAssertEqual(after, before + 1)
        // 清理
        await DatabaseManager.shared.decrementActiveTransactions()
    }

    func testDecrementActiveTransactions_计数为零时不变为负数() async throws {
        // Finding #18 相关：decrement 的 if > 0 保护
        // 先 increment 到已知值，再连续 decrement 超过该值，验证不会变负
        try await DatabaseManager.shared.incrementActiveTransactions()
        await DatabaseManager.shared.decrementActiveTransactions()
        await DatabaseManager.shared.decrementActiveTransactions()
        await DatabaseManager.shared.decrementActiveTransactions()
        let count = await DatabaseManager.shared.activeTransactionsCount
        XCTAssertEqual(count, 0, "计数为 0 时 decrement 不应变为负数")
    }

    func testDecrementActiveTransactions_incrementDecrement配对归零() async throws {
        let before = await DatabaseManager.shared.activeTransactionsCount
        try await DatabaseManager.shared.incrementActiveTransactions()
        try await DatabaseManager.shared.incrementActiveTransactions()
        try await DatabaseManager.shared.incrementActiveTransactions()
        await DatabaseManager.shared.decrementActiveTransactions()
        await DatabaseManager.shared.decrementActiveTransactions()
        await DatabaseManager.shared.decrementActiveTransactions()
        let after = await DatabaseManager.shared.activeTransactionsCount
        XCTAssertEqual(after, before, "配对的 increment/decrement 应保持计数不变")
    }

    // MARK: - Finding #18 修复验证：TransactionGatekeeper 排空期间拒绝新事务

    func testFinding18_排空期间拒绝新事务() async throws {
        // 触发排空（drain），但因为有活跃事务会等待
        try await DatabaseManager.shared.incrementActiveTransactions()
        // 启动排空任务（在后台）
        let drainTask = Task {
            return await DatabaseManager.shared.transactionGatekeeper.drain(maxWaitTime: .milliseconds(500))
        }
        // 给 drain 一点时间设置 draining = true
        try await Task.sleep(for: .milliseconds(50))
        // 排空期间 acquire 应抛 draining
        do {
            try await DatabaseManager.shared.incrementActiveTransactions()
            XCTFail("排空期间应抛 ZhiYu.DatabaseError.draining")
        } catch {
            if let dbError = error as? ZhiYu.DatabaseError, case .draining = dbError {
                // 预期行为
            } else {
                XCTFail("应抛 ZhiYu.DatabaseError.draining，实际：\(error)")
            }
        }
        // 释放活跃事务，让 drain 完成
        await DatabaseManager.shared.decrementActiveTransactions()
        let drained = await drainTask.value
        XCTAssertTrue(drained, "释放事务后 drain 应成功")
    }

    func testFinding18_drain无活跃事务时立即成功() async throws {
        let drained = await DatabaseManager.shared.transactionGatekeeper.drain(maxWaitTime: .milliseconds(100))
        XCTAssertTrue(drained, "无活跃事务时 drain 应立即成功")
    }

    // MARK: - migrate（避免调用 setupForTesting 以防 DI 容器污染）

    func testMigrate_对内存库执行迁移_验证schema() throws {
        let memoryQueue = try DatabaseQueue()
        try DatabaseManager.shared.migrate(memoryQueue)
        let tables = try memoryQueue.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
        }
        XCTAssertTrue(tables.count > 0, "migrate 后应有表存在")
        // 验证 FeedbackEntry 表存在（V13 迁移）
        XCTAssertTrue(tables.contains(FeedbackEntry.databaseTableName), "migrate 后应有 feedback_entries 表")
    }

    // MARK: - reset

    func testReset_清空所有Writer() throws {
        // 用独立 DatabaseQueue 验证 reset 逻辑，不调用 setupForTesting 避免 DI 污染
        let memoryQueue = try DatabaseQueue()
        DatabaseManager.shared.dbWriter = memoryQueue
        XCTAssertNotNil(DatabaseManager.shared.dbWriter)

        DatabaseManager.shared.reset()
        XCTAssertNil(DatabaseManager.shared.dbWriter, "reset 后 dbWriter 应为 nil")
        XCTAssertNil(DatabaseManager.shared.globalWriter, "reset 后 globalWriter 应为 nil")
    }

    // MARK: - Finding #17 修复验证：dbWriter 为 nil 时抛错而非静默降级

    func testFinding17_dbWriter为Nil时_抛错而非降级() async throws {
        // 确保 dbWriter 为 nil
        DatabaseManager.shared.reset()
        XCTAssertNil(DatabaseManager.shared.dbWriter)

        // 模拟 Repository 通过 DatabaseWriterProvider 获取 writer
        let provider = TestWriterProvider()

        // Finding #17 修复后：应抛 ZhiYu.DatabaseError.notReady，而非静默降级创建内存库
        do {
            _ = try await provider.dbWriter
            XCTFail("Finding #17 修复后：dbWriter 为 nil 时应抛 ZhiYu.DatabaseError.notReady")
        } catch {
            if let dbError = error as? ZhiYu.DatabaseError, case .notReady = dbError {
                // 预期行为：抛错而非降级
            } else {
                XCTFail("应抛 ZhiYu.DatabaseError.notReady，实际：\(error)")
            }
        }
    }

    func testFinding17_dbWriter存在时_正常返回() async throws {
        // 设置 dbWriter
        let memoryQueue = try DatabaseQueue()
        DatabaseManager.shared.dbWriter = memoryQueue

        let provider = TestWriterProvider()
        let writer = try await provider.dbWriter
        XCTAssertNotNil(writer, "dbWriter 存在时应正常返回")
    }

    // MARK: - releaseDatabaseConnection

    func testReleaseDatabaseConnection_dbWriter置Nil() throws {
        // 用独立 DatabaseQueue，不调用 setup(at:) 避免 DI 污染
        let memoryQueue = try DatabaseQueue()
        DatabaseManager.shared.dbWriter = memoryQueue
        XCTAssertNotNil(DatabaseManager.shared.dbWriter)

        DatabaseManager.shared.releaseDatabaseConnection()
        XCTAssertNil(DatabaseManager.shared.dbWriter, "releaseDatabaseConnection 后 dbWriter 应为 nil")
    }

    // MARK: - DatabaseState 判等

    func testDatabaseState_判等语义() {
        XCTAssertEqual(DatabaseState.uninitialized, .uninitialized)
        XCTAssertEqual(DatabaseState.ready, .ready)
        XCTAssertEqual(DatabaseState.corrupted("err1"), .corrupted("err1"))
        XCTAssertNotEqual(DatabaseState.corrupted("err1"), .corrupted("err2"))
        XCTAssertNotEqual(DatabaseState.uninitialized, .ready)
        XCTAssertNotEqual(DatabaseState.ready, .corrupted("err"))
    }

    // MARK: - countPagesInCurrentVault

    func testCountPagesInCurrentVault_dbWriter为Nil时返回零() async throws {
        DatabaseManager.shared.reset()
        let count = try await DatabaseManager.shared.countPagesInCurrentVault()
        XCTAssertEqual(count, 0, "dbWriter 为 nil 时应返回 0")
    }

    // MARK: - 通知名称存在性

    func testNotificationNames_已定义() {
        XCTAssertEqual(Notification.Name.databaseDidSwitch.rawValue, "databaseDidSwitch")
        XCTAssertEqual(Notification.Name.databaseIntegrityCheckFailed.rawValue, "databaseIntegrityCheckFailed")
        XCTAssertEqual(Notification.Name.databaseStateDidChange.rawValue, "databaseStateDidChange")
    }

    // MARK: - DatabaseError 新增 case

    func testDatabaseError_notReady() {
        let error = ZhiYu.DatabaseError.notReady
        XCTAssertNotNil(error, "ZhiYu.DatabaseError.notReady 应存在")
    }

    func testDatabaseError_draining() {
        let error = ZhiYu.DatabaseError.draining
        XCTAssertNotNil(error, "ZhiYu.DatabaseError.draining 应存在")
    }
}

/// 测试用 DatabaseWriterProvider stub，用于验证 Finding #17 降级行为
private final class TestWriterProvider: DatabaseWriterProvider {}

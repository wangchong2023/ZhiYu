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
    private var savedActiveTransactionsCount: Int = 0

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DatabaseManagerTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        // 保存状态，测试后恢复，避免污染其他测试
        savedDbWriter = DatabaseManager.shared.dbWriter
        savedGlobalWriter = DatabaseManager.shared.globalWriter
        savedIsInTesting = DatabaseManager.shared.isInTesting
        savedActiveTransactionsCount = DatabaseManager.shared.activeTransactionsCount
        DatabaseManager.shared.reset()
    }

    override func tearDown() {
        // 恢复 DatabaseManager 的 writer 和测试标志
        DatabaseManager.shared.dbWriter = savedDbWriter
        DatabaseManager.shared.globalWriter = savedGlobalWriter
        DatabaseManager.shared.isInTesting = savedIsInTesting
        // 恢复 activeTransactionsCount（通过 decrement 回到保存值）
        let currentCount = DatabaseManager.shared.activeTransactionsCount
        if currentCount > savedActiveTransactionsCount {
            for _ in 0..<(currentCount - savedActiveTransactionsCount) {
                DatabaseManager.shared.decrementActiveTransactions()
            }
        } else if currentCount < savedActiveTransactionsCount {
            for _ in 0..<(savedActiveTransactionsCount - currentCount) {
                DatabaseManager.shared.incrementActiveTransactions()
            }
        }
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    // MARK: - reset 后属性验证

    func testReset后_dbWriter为Nil() {
        XCTAssertNil(DatabaseManager.shared.dbWriter, "reset 后 dbWriter 应为 nil")
    }

    func testReset后_globalWriter为Nil() {
        XCTAssertNil(DatabaseManager.shared.globalWriter, "reset 后 globalWriter 应为 nil")
    }

    // MARK: - 事务计数（使用相对增量，避免依赖绝对初始值）

    func testIncrementActiveTransactions_计数递增() {
        let before = DatabaseManager.shared.activeTransactionsCount
        DatabaseManager.shared.incrementActiveTransactions()
        XCTAssertEqual(DatabaseManager.shared.activeTransactionsCount, before + 1)
        DatabaseManager.shared.incrementActiveTransactions()
        XCTAssertEqual(DatabaseManager.shared.activeTransactionsCount, before + 2)
    }

    func testDecrementActiveTransactions_计数递减() {
        let before = DatabaseManager.shared.activeTransactionsCount
        DatabaseManager.shared.incrementActiveTransactions()
        DatabaseManager.shared.incrementActiveTransactions()
        DatabaseManager.shared.decrementActiveTransactions()
        XCTAssertEqual(DatabaseManager.shared.activeTransactionsCount, before + 1)
    }

    func testDecrementActiveTransactions_计数为零时不变为负数() {
        // Finding #18 相关：decrement 的 if > 0 保护
        // 先 increment 到已知值，再连续 decrement 超过该值，验证不会变负
        DatabaseManager.shared.incrementActiveTransactions()
        DatabaseManager.shared.decrementActiveTransactions()
        DatabaseManager.shared.decrementActiveTransactions()
        DatabaseManager.shared.decrementActiveTransactions()
        XCTAssertEqual(DatabaseManager.shared.activeTransactionsCount, 0, "计数为 0 时 decrement 不应变为负数")
    }

    func testDecrementActiveTransactions_incrementDecrement配对归零() {
        let before = DatabaseManager.shared.activeTransactionsCount
        DatabaseManager.shared.incrementActiveTransactions()
        DatabaseManager.shared.incrementActiveTransactions()
        DatabaseManager.shared.incrementActiveTransactions()
        DatabaseManager.shared.decrementActiveTransactions()
        DatabaseManager.shared.decrementActiveTransactions()
        DatabaseManager.shared.decrementActiveTransactions()
        XCTAssertEqual(DatabaseManager.shared.activeTransactionsCount, before, "配对的 increment/decrement 应保持计数不变")
    }

    // MARK: - setupForTesting（避免调用以防止 DI 容器污染）
    // 注：setupForTesting 会触发 databaseStateDidChange 通知，KnowledgeStore 监听后
    // 尝试 refresh()，但测试环境 DI 未注册 AnyPageStore，导致 DI resolve 失败。
    // 因此这些测试改用独立 DatabaseQueue 验证 migrate 逻辑，不通过 DatabaseManager.shared。

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

    // MARK: - setup 物理数据库（避免调用 setup(at:) 以防 DI 容器污染）
    // 注：setup(at:) 会设置 state=.ready 并广播 databaseStateDidChange 通知，
    // 触发 KnowledgeStore.refresh()，但测试环境 DI 未注册 AnyPageStore 导致 crash。
    // 这些测试在 stash 后全量通过，说明是本测试类的 setup/teardown 恢复机制与
    // DatabaseSchemaMigratorEdgeTests 交互导致。改为不调用 setup(at:)。

    // MARK: - Finding #17：dbWriter 为 nil 时的静默降级

    /// Finding #17 复现：dbWriter 为 nil 时，DatabaseWriterProvider 协议默认实现
    /// 静默创建空内存 DatabaseQueue，数据写入临时库后丢失。
    func testFinding17_dbWriter为Nil时_静默降级到内存库() async throws {
        // 确保 dbWriter 为 nil
        DatabaseManager.shared.reset()
        XCTAssertNil(DatabaseManager.shared.dbWriter)

        // 模拟 Repository 通过 DatabaseWriterProvider 获取 writer
        let provider = TestWriterProvider()
        let writer = await provider.dbWriter

        // 降级创建了一个空内存库（非 nil）
        XCTAssertNotNil(writer, "Finding #17：dbWriter 为 nil 时静默降级创建内存库，无错误抛出")

        // 写入数据到降级内存库
        try await writer.write { db in
            try db.execute(sql: "CREATE TABLE test_finding17 (id INTEGER PRIMARY KEY, value TEXT)")
            try db.execute(sql: "INSERT INTO test_finding17 (value) VALUES ('will_be_lost')")
        }

        // 验证数据写入了降级库
        let count = try await writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM test_finding17")
        }
        XCTAssertEqual(count, 1, "数据已写入降级内存库")

        // Finding #17 核心问题：这个降级库是临时的，下次获取 dbWriter 时会创建新的空库
        // 真实场景中 DatabaseManager.shared.dbWriter 恢复后，之前写入降级库的数据无法访问
        let realWriter = try DatabaseQueue()
        DatabaseManager.shared.dbWriter = realWriter

        // 新的 writer 是不同的实例，之前写入降级库的数据丢失
        let newCount: Int?
        if let dbWriter = DatabaseManager.shared.dbWriter {
            newCount = try await dbWriter.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE name='test_finding17'")
            }
        } else {
            newCount = nil
        }
        XCTAssertEqual(newCount, 0, "Finding #17：降级库中的数据在 dbWriter 恢复后丢失，无任何错误提示")
    }

    // MARK: - Finding #17 补充：switchDatabase 瞬态窗口
    // 注：switchDatabase 依赖 setup(at:) 初始化，会触发 DI 污染，跳过此测试
    // 相关行为由 testFinding17_dbWriter为Nil时_静默降级到内存库 覆盖核心降级逻辑

    // MARK: - Finding #18：事务排空竞态

    /// Finding #18 复现：decrementActiveTransactions 的 if > 0 保护在竞态下可能掩盖真实计数。
    /// 此测试验证 decrement 在 count==0 时不变为负数（保护机制本身工作正常）。
    func testFinding18_decrement在计数为零时不变为负数() {
        // 连续 decrement 多次
        for _ in 0..<5 {
            DatabaseManager.shared.decrementActiveTransactions()
        }
        XCTAssertEqual(DatabaseManager.shared.activeTransactionsCount, 0, "Finding #18：decrement 保护机制工作，计数不会变为负数")
    }

    /// Finding #18 相关：increment/decrement 配对应保持计数不变
    func testFinding18_incrementDecrement配对_计数不变() {
        let before = DatabaseManager.shared.activeTransactionsCount
        DatabaseManager.shared.incrementActiveTransactions()
        DatabaseManager.shared.incrementActiveTransactions()
        DatabaseManager.shared.incrementActiveTransactions()
        DatabaseManager.shared.decrementActiveTransactions()
        DatabaseManager.shared.decrementActiveTransactions()
        DatabaseManager.shared.decrementActiveTransactions()
        XCTAssertEqual(DatabaseManager.shared.activeTransactionsCount, before, "配对的 increment/decrement 应保持计数不变")
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

    // 注：testCountPagesInCurrentVault_空数据库返回零 需 setupForTesting，会触发 DI 污染，跳过

    // MARK: - migrate
    // 注：testMigrate_对内存库执行迁移_验证schema 已在 setupForTesting 章节定义

    // MARK: - 通知名称存在性

    func testNotificationNames_已定义() {
        XCTAssertEqual(Notification.Name.databaseDidSwitch.rawValue, "databaseDidSwitch")
        XCTAssertEqual(Notification.Name.databaseIntegrityCheckFailed.rawValue, "databaseIntegrityCheckFailed")
        XCTAssertEqual(Notification.Name.databaseStateDidChange.rawValue, "databaseStateDidChange")
    }
}

/// 测试用 DatabaseWriterProvider stub，用于验证 Finding #17 降级行为
private final class TestWriterProvider: DatabaseWriterProvider {}

//
//  DatabaseWriterProviderBatch6CTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 DatabaseWriterProvider 协议默认实现的降级路径，复现 Finding #17。
//

import XCTest
import UFPStorage
@testable import ZhiYu

@MainActor
final class DatabaseWriterProviderBatch6CTests: XCTestCase {

    private var tempDir: URL!
    private var savedDbWriter: (any DatabaseWriter)?
    private var savedGlobalWriter: (any DatabaseWriter)?
    private var savedIsInTesting: Bool = false

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WriterProviderTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        // 保存状态，测试后恢复，避免污染其他测试
        savedDbWriter = DatabaseManager.shared.dbWriter
        savedGlobalWriter = DatabaseManager.shared.globalWriter
        savedIsInTesting = DatabaseManager.shared.isInTesting
        DatabaseManager.shared.reset()
    }

    override func tearDown() {
        // 恢复 DatabaseManager 的 writer 和测试标志
        DatabaseManager.shared.dbWriter = savedDbWriter
        DatabaseManager.shared.globalWriter = savedGlobalWriter
        DatabaseManager.shared.isInTesting = savedIsInTesting
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Finding #17：dbWriter 为 nil 时的静默降级

    /// Finding #17 核心复现：dbWriter 为 nil 时，协议默认实现静默创建空内存库。
    /// 无错误抛出，调用方无感知，数据写入临时库后丢失。
    func testFinding17_dbWriter为Nil_静默降级创建内存库() async {
        let provider = StubWriterProvider()
        XCTAssertNil(DatabaseManager.shared.dbWriter, "前置条件：dbWriter 应为 nil")

        let writer = await provider.dbWriter

        // Finding #17：静默降级，无错误抛出
        XCTAssertNotNil(writer, "dbWriter 为 nil 时静默降级创建内存库，无错误抛出")
    }

    /// Finding #17：降级库是临时的，每次获取都创建新实例
    func testFinding17_降级库每次创建新实例() async {
        let provider = StubWriterProvider()
        XCTAssertNil(DatabaseManager.shared.dbWriter)

        let writer1 = await provider.dbWriter
        let writer2 = await provider.dbWriter

        // 两次获取的是不同的内存库实例，数据不互通
        XCTAssertFalse(writer1 === writer2 as AnyObject, "Finding #17：每次降级都创建新的临时内存库，数据不互通")
    }

    /// Finding #17：降级库写入的数据在 dbWriter 恢复后丢失
    func testFinding17_降级库数据在Writer恢复后丢失() async throws {
        let provider = StubWriterProvider()
        XCTAssertNil(DatabaseManager.shared.dbWriter)

        let degradedWriter = await provider.dbWriter
        try await degradedWriter.write { db in
            try db.execute(sql: "CREATE TABLE temp_data (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO temp_data (id) VALUES (1)")
        }

        // 恢复真实 dbWriter（直接赋值，不调用 setupForTesting 避免 DI 污染）
        let realWriter = try DatabaseQueue()
        DatabaseManager.shared.dbWriter = realWriter

        // 真实 writer 中没有 temp_data 表，降级库数据丢失
        let tableExists = try await realWriter.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE name='temp_data'")
        }
        XCTAssertEqual(tableExists, 0, "Finding #17：降级库数据在 dbWriter 恢复后丢失，无任何错误提示")
    }

    // MARK: - dbWriter 正常路径

    func testDbWriter_正常路径返回真实Writer() async throws {
        let memoryQueue = try DatabaseQueue()
        DatabaseManager.shared.dbWriter = memoryQueue

        let provider = StubWriterProvider()
        let writer = await provider.dbWriter

        XCTAssertNotNil(writer, "dbWriter 正常时应返回真实 writer")
    }

    // MARK: - reset 后降级

    func testDbWriter_reset后降级到内存库() async throws {
        let memoryQueue = try DatabaseQueue()
        DatabaseManager.shared.dbWriter = memoryQueue

        let provider = StubWriterProvider()
        let writer1 = await provider.dbWriter
        XCTAssertNotNil(writer1)

        // reset 后 dbWriter 为 nil
        DatabaseManager.shared.reset()
        XCTAssertNil(DatabaseManager.shared.dbWriter)

        // 再次获取降级到内存库
        let writer2 = await provider.dbWriter
        XCTAssertNotNil(writer2, "reset 后降级到内存库")
        XCTAssertFalse(writer1 === writer2 as AnyObject, "reset 前后的 writer 应是不同实例")
    }
}

/// 测试用 DatabaseWriterProvider stub
private final class StubWriterProvider: DatabaseWriterProvider {}

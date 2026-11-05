//
//  GenericSQLiteEngineTests.swift
//  UFPStorageTests
//
//  系统层级：[UFPStorageTests]
//  核心职责：验证 GenericSQLiteEngine 泛型 CRUD（write/read/insertAll/fetchAll/deleteAll/count）
//           在内存 GRDB 连接上的行为与幂等语义。
//

import XCTest
import GRDB
@testable import UFPStorage

/// 测试用泛型记录模型：与业务无关，仅用于验证引擎的泛型约束。
private struct TestRecord: Codable, Sendable,
    TableRecord, MutablePersistableRecord, FetchableRecord {
    static let databaseTableName = "test_records"

    var id: Int64?
    var name: String

    init(id: Int64? = nil, name: String) {
        self.id = id
        self.name = name
    }

    init(row: Row) {
        id = row["id"]
        name = row["name"]
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
    }
}

final class GenericSQLiteEngineTests: XCTestCase {

    private var dbQueue: DatabaseQueue!
    private var engine: GenericSQLiteEngine!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: TestRecord.databaseTableName) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
            }
        }
        engine = GenericSQLiteEngine(writer: dbQueue)
    }

    override func tearDown() async throws {
        engine = nil
        dbQueue = nil
        try await super.tearDown()
    }

    // MARK: - 通用 write/read

    func testWrite_ExecutesBlock_AndReadReturnsValue() async throws {
        // Given — 引擎与内存连接已就绪
        // When — 通过 write 插入，再通过 read 统计
        let inserted = try await engine.write { db in
            var newRecord = TestRecord(name: "引擎写入")
            try newRecord.insert(db)
            return newRecord
        }
        let count = try await engine.read { db in
            try TestRecord.fetchCount(db)
        }

        // Then
        XCTAssertNotNil(inserted.id, "write 应返回插入后带 rowID 的记录")
        XCTAssertEqual(count, 1, "read 应能读到 write 写入的记录")
    }

    // MARK: - 泛型 CRUD

    func testInsertAll_ThenFetchAll_ReturnsAll() async throws {
        // Given
        let records = (1...5).map { TestRecord(name: "record-\($0)") }

        // When
        try await engine.insertAll(records)
        let fetched = try await engine.fetchAll(TestRecord.self)

        // Then
        XCTAssertEqual(fetched.count, 5, "插入 5 条后应能取回 5 条")
        XCTAssertEqual(Set(fetched.map(\.name)), Set(records.map(\.name)), "取回的记录名应与插入一致")
    }

    func testCount_AfterInsert_ReflectsRowCount() async throws {
        // Given
        try await engine.insertAll([TestRecord(name: "a"), TestRecord(name: "b")])

        // When
        let count = try await engine.count(TestRecord.self)

        // Then
        XCTAssertEqual(count, 2, "count 应等于插入条数")
    }

    func testDeleteAll_EmptiesTable() async throws {
        // Given
        try await engine.insertAll([TestRecord(name: "x"), TestRecord(name: "y")])

        // When
        try await engine.deleteAll(TestRecord.self)
        let count = try await engine.count(TestRecord.self)

        // Then
        XCTAssertEqual(count, 0, "deleteAll 后表应为空")
    }

    func testDeleteAll_OnEmptyTable_IsIdempotent() async throws {
        // Given — 空表

        // When
        try await engine.deleteAll(TestRecord.self)

        // Then
        let count = try await engine.count(TestRecord.self)
        XCTAssertEqual(count, 0, "对空表 deleteAll 不应报错且仍为空")
    }

    // MARK: - 事务回滚语义

    func testWrite_WhenBlockThrows_RollsBackChanges() async throws {
        // Given — 先插入一条成功记录
        try await engine.insertAll([TestRecord(name: "keep")])

        // When — 第二条插入触发唯一约束错误，应整体回滚
        struct ConstraintError: Error {}
        do {
            try await engine.write { db in
                var newRecord = TestRecord(name: "will-rollback")
                try newRecord.insert(db)
                throw ConstraintError()
            }
            XCTFail("write 应抛出错误")
        } catch {
            // 预期抛出
        }

        // Then — 第一条记录仍在（回滚未影响既有数据），新记录未写入
        let names = try await engine.fetchAll(TestRecord.self).map(\.name)
        XCTAssertEqual(names, ["keep"], "write 抛错后不应残留未提交记录")
    }
}
//
//  GRDBRuntimeIntegrationTests.swift
//  UFPStorageTests
//
//  系统层级：[UFPStorageTests]
//  核心职责：验证 GRDB 在运行时的实际可用性（编译期可见性 + 运行时实例化）。
//           确保 @_exported 不仅暴露类型符号，还能实际创建数据库连接。
//

import XCTest
@testable import UFPStorage

final class GRDBRuntimeIntegrationTests: XCTestCase {

    /// 必须能创建内存数据库 DatabaseQueue（GRDB 最基础能力）
    func testCreateInMemoryDatabaseQueue() throws {
        let dbQueue = try DatabaseQueue()
        XCTAssertNotNil(dbQueue)
    }

    /// 内存数据库必须能执行基础 SQL
    func testInMemoryDatabaseExecutesSQL() throws {
        let dbQueue = try DatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")
            try db.execute(sql: "INSERT INTO test (name) VALUES ('hello')")
        }

        let count = try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM test")
        }
        XCTAssertEqual(count, 1)
    }

    /// 内存数据库必须支持事务回滚
    func testTransactionRollback() throws {
        let dbQueue = try DatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE test (id INTEGER PRIMARY KEY)")
        }

        do {
            try dbQueue.inTransaction { db in
                try db.execute(sql: "INSERT INTO test (id) VALUES (1)")
                throw NSError(domain: "test", code: 1) // 故意抛错触发回滚
            }
            XCTFail("事务应已回滚并抛出错误")
        } catch {
            // 预期错误
        }

        let count = try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM test")
        }
        XCTAssertEqual(count, 0, "事务回滚后不应有数据残留")
    }

    /// GRDB 的 Row 类型必须能解析查询结果
    func testGRDBRowParsing() throws {
        let dbQueue = try DatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE test (id INTEGER, name TEXT)")
            try db.execute(sql: "INSERT INTO test VALUES (1, 'alice')")
        }

        let rows = try dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM test")
        }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["id"], 1)
        XCTAssertEqual(rows[0]["name"], "alice")
    }

    /// GRDB 必须支持 FTS5（如果编译启用）
    func testFTS5Availability() throws {
        let dbQueue = try DatabaseQueue()
        try dbQueue.write { db in
            // FTS5 虚拟表创建语法
            try db.execute(sql: "CREATE VIRTUAL TABLE search USING fts5(content)")
            try db.execute(sql: "INSERT INTO search VALUES ('hello world')")
        }

        let results = try dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT content FROM search WHERE search MATCH 'hello'")
        }
        XCTAssertEqual(results, ["hello world"])
    }
}

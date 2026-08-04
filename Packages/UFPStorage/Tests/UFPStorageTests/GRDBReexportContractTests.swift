//
//  GRDBReexportContractTests.swift
//  UFPStorageTests
//
//  系统层级：[UFPStorageTests]
//  核心职责：验证 GRDB 通过 @_exported 透明重导出的契约。
//           上层模块 import UFPStorage 后必须能直接使用 GRDB 类型，无需 import GRDB。
//

import XCTest
@testable import UFPStorage

final class GRDBReexportContractTests: XCTestCase {

    /// import UFPStorage 后必须能访问 GRDB 的核心类型（DatabaseQueue）
    func testGRDBDatabaseQueueAccessibleViaUFPStorage() {
        // DatabaseQueue 是 GRDB 的核心入口类型
        // 若 @_exported 失效，此行会编译错误
        let typeString = String(describing: DatabaseQueue.self)
        XCTAssertTrue(typeString.contains("DatabaseQueue"),
                      "import UFPStorage 后必须能访问 GRDB.DatabaseQueue")
    }

    /// import UFPStorage 后必须能访问 GRDB 的 Record 类型
    func testGRDBRecordAccessibleViaUFPStorage() {
        let typeString = String(describing: Record.self)
        XCTAssertTrue(typeString.contains("Record"))
    }

    /// import UFPStorage 后必须能访问 GRDB 的 FetchableRecord 协议
    func testGRDBFetchableRecordAccessibleViaUFPStorage() {
        let typeString = String(describing: FetchableRecord.self)
        XCTAssertTrue(typeString.contains("FetchableRecord"))
    }

    /// import UFPStorage 后必须能访问 GRDB 的 PersistableRecord 协议
    func testGRDBPersistableRecordAccessibleViaUFPStorage() {
        let typeString = String(describing: PersistableRecord.self)
        XCTAssertTrue(typeString.contains("PersistableRecord"))
    }

    /// GRDB 的 SQL 表达式类型必须可访问
    func testGRDBSQLExpressionAccessible() {
        let typeString = String(describing: SQLExpression.self)
        XCTAssertTrue(typeString.contains("SQL"))
    }

    /// GRDB 的 Column 类型必须可访问
    func testGRDBColumnAccessible() {
        let typeString = String(describing: Column.self)
        XCTAssertTrue(typeString.contains("Column"))
    }
}

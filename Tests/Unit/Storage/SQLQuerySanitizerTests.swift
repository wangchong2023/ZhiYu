//
//  SQLQuerySanitizerTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：测试 SQLQuerySanitizer 的通配符转义、空白查询防护与安全模式生成。
//

import XCTest
@testable import ZhiYu

final class SQLQuerySanitizerTests: XCTestCase {

    // MARK: - 1. 通配符转义测试

    func testMakeLikePattern_NormalQuery() {
        let pattern = SQLQuerySanitizer.makeLikePattern("Karpathy")
        XCTAssertEqual(pattern, "%Karpathy%")
    }

    func testMakeLikePattern_EscapesPercentWildcard() {
        let pattern = SQLQuerySanitizer.makeLikePattern("100%覆盖率")
        XCTAssertEqual(pattern, "%100\\%覆盖率%")
    }

    func testMakeLikePattern_EscapesUnderscoreWildcard() {
        let pattern = SQLQuerySanitizer.makeLikePattern("var_name")
        XCTAssertEqual(pattern, "%var\\_name%")
    }

    func testMakeLikePattern_EscapesBackslash() {
        let pattern = SQLQuerySanitizer.makeLikePattern("path\\to\\file")
        XCTAssertEqual(pattern, "%path\\\\to\\\\file%")
    }

    func testMakeLikePattern_ComplexSpecialCharacters() {
        let pattern = SQLQuerySanitizer.makeLikePattern("%_\\test")
        XCTAssertEqual(pattern, "%\\%\\_\\\\test%")
    }

    // MARK: - 2. 空白查询判定

    func testIsValidQuery_EmptyAndWhitespace() {
        XCTAssertFalse(SQLQuerySanitizer.isValidQuery(""))
        XCTAssertFalse(SQLQuerySanitizer.isValidQuery("   "))
        XCTAssertFalse(SQLQuerySanitizer.isValidQuery("\n\t  \r"))
    }

    func testIsValidQuery_ValidQueries() {
        XCTAssertTrue(SQLQuerySanitizer.isValidQuery("a"))
        XCTAssertTrue(SQLQuerySanitizer.isValidQuery(" 智宇 "))
        XCTAssertTrue(SQLQuerySanitizer.isValidQuery("LLM RAG"))
    }
}

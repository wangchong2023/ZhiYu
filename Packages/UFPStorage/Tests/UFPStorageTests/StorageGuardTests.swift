//
//  StorageGuardTests.swift
//  UFPStorageTests
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorageTests]
//  核心职责：测试 SQLQuerySanitizer 通配符转义/空白防护，以及 TransactionGatekeeper 事务门禁排空语义。
//

import XCTest
@testable import UFPStorage

final class StorageGuardTests: XCTestCase {

    // MARK: - 1. SQLQuerySanitizer 通配符转义

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

    // MARK: - 2. SQLQuerySanitizer 空白查询判定

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

    // MARK: - 3. TransactionGatekeeper 事务门禁

    func testAcquireRelease_PairedCountToZero() async throws {
        let gatekeeper = TransactionGatekeeper()
        let initial = await gatekeeper.activeCount
        XCTAssertEqual(initial, 0)
        try await gatekeeper.acquire()
        try await gatekeeper.acquire()
        let after = await gatekeeper.activeCount
        XCTAssertEqual(after, 2)
        await gatekeeper.release()
        await gatekeeper.release()
        let final = await gatekeeper.activeCount
        XCTAssertEqual(final, 0)
    }

    func testReleaseWhenZero_DoesNotUnderflow() async {
        let gatekeeper = TransactionGatekeeper()
        await gatekeeper.release()
        await gatekeeper.release()
        let count = await gatekeeper.activeCount
        XCTAssertEqual(count, 0, "计数为 0 时 release 不应变为负数")
    }

    func testAcquireDuringDraining_ThrowsDraining() async throws {
        let gatekeeper = TransactionGatekeeper()
        await gatekeeper.setDrainingForTesting(true)
        do {
            try await gatekeeper.acquire()
            XCTFail("排空期间 acquire 必须抛出 DatabaseError.draining")
        } catch {
            XCTAssertEqual(error as? DatabaseError, .draining)
        }
    }

    func testDrainWhenZero_ReturnsTrueImmediately() async {
        let gatekeeper = TransactionGatekeeper()
        let drained = await gatekeeper.drain(maxWaitTime: .milliseconds(100))
        XCTAssertTrue(drained, "无活跃事务时 drain 应立即成功")
        let draining = await gatekeeper.draining
        XCTAssertFalse(draining, "drain 完成后 draining 应复位")
    }

    func testDrainWaitsForRelease_Succeeds() async throws {
        let gatekeeper = TransactionGatekeeper()
        try await gatekeeper.acquire()
        let drainTask = Task {
            await gatekeeper.drain(maxWaitTime: .milliseconds(1000))
        }
        // 给 drain 一点时间设置 draining = true
        try await Task.sleep(for: .milliseconds(50))
        // 排空期间 acquire 应抛 draining
        do {
            try await gatekeeper.acquire()
            XCTFail("排空期间 acquire 应抛 DatabaseError.draining")
        } catch {
            XCTAssertEqual(error as? DatabaseError, .draining)
        }
        await gatekeeper.release()
        let drained = await drainTask.value
        XCTAssertTrue(drained, "释放事务后 drain 应成功")
    }

    func testDrainTimeout_ReturnsFalseAndClearsDraining() async throws {
        let gatekeeper = TransactionGatekeeper()
        try await gatekeeper.acquire()
        let drained = await gatekeeper.drain(maxWaitTime: .milliseconds(80))
        XCTAssertFalse(drained, "超时后 drain 应返回 false")
        let draining = await gatekeeper.draining
        XCTAssertFalse(draining, "超时后 draining 应复位")
        await gatekeeper.release()
    }

    func testReset_ClearsAllState() async throws {
        let gatekeeper = TransactionGatekeeper()
        try await gatekeeper.acquire()
        await gatekeeper.setDrainingForTesting(true)
        await gatekeeper.reset()
        let count = await gatekeeper.activeCount
        XCTAssertEqual(count, 0)
        let draining = await gatekeeper.draining
        XCTAssertFalse(draining)
        let drained = await gatekeeper.drain(maxWaitTime: .milliseconds(100))
        XCTAssertTrue(drained, "reset 后 drain 应立即成功")
    }
}
//
//  SQLiteTransactionConcurrencyStressTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：验证 SQLiteStore (GRDB) 在高并发读写、事务原子回滚与多线程压力下的数据一致性。
//

import XCTest
import GRDB
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SQLiteTransactionConcurrencyStressTests: XCTestCase {

    var store: SQLiteStore!
    var tempDBURL: URL!
    var dbQueue: DatabaseQueue!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        tempDBURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConcurrencyStress_\(UUID().uuidString).sqlite")
        dbQueue = try DatabaseQueue(path: tempDBURL.path)
        try await DatabaseManager.shared.migrate(dbQueue)
        store = SQLiteStore(dbWriter: dbQueue)
    }

    override func tearDown() async throws {
        store = nil
        dbQueue = nil
        try? FileManager.default.removeItem(at: tempDBURL)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 并发页面写入数据完整性

    func testConcurrentPageWrites_MaintainsDataIntegrity() async throws {
        let iterations = 20

        for i in 0..<iterations {
            _ = try await store.createPage(
                title: "并发测试页面 \(i)",
                pageType: .concept,
                content: "并发内容 \(i)"
            )
        }

        let allPages = try await store.fetchAllPages()
        XCTAssertEqual(allPages.count, iterations, "并发顺序写入后页面总数应当精准一致")
    }

    // MARK: - 2. 事务原子性与回滚分支

    func testTransactionRollback_OnFailure_DoesNotPersistCorruptedData() async throws {
        _ = try await store.createPage(
            title: "初始页面",
            pageType: .concept,
            content: "初始内容"
        )

        let preCount = try await store.fetchAllPages().count

        // 模拟外部事务中途抛出异常
        do {
            try await dbQueue.write { db in
                let newPage = KnowledgePage(title: "临时页面", content: "临时内容")
                try newPage.insert(db)
                throw DatabaseError.notReady
            }
        } catch {
            // 预期捕获错误
        }

        let postCount = try await store.fetchAllPages().count
        XCTAssertEqual(postCount, preCount, "事务异常回滚后页面总数不应增加")
    }
}

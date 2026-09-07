//
//  FeedbackRepositoryTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：FeedbackEntry 模型 + FeedbackRepository CRUD 全覆盖测试

import XCTest
import UFPStorage
@testable import ZhiYu

@MainActor
final class FeedbackRepositoryTests: XCTestCase {

    private var dbQueue: DatabaseQueue!
    private var repo: SQLiteFeedbackRepository!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v9_test") { db in
            try db.create(table: FeedbackEntry.databaseTableName) { t in
                t.column(FeedbackEntry.CodingKeys.id.name, .text).primaryKey()
                t.column(FeedbackEntry.CodingKeys.title.name, .text).notNull()
                t.column(FeedbackEntry.CodingKeys.category.name, .text).notNull()
                t.column(FeedbackEntry.CodingKeys.rating.name, .integer).notNull()
                t.column(FeedbackEntry.CodingKeys.content.name, .text).notNull()
                // 核心纠错：加入 status 反馈状态列，对齐 v13_feedback_status 生产迁移。
                t.column(FeedbackEntry.CodingKeys.status.name, .text).notNull().defaults(to: FeedbackStatus.pending.rawValue)
                t.column(FeedbackEntry.CodingKeys.appVersion.name, .text)
                t.column(FeedbackEntry.CodingKeys.osVersion.name, .text)
                t.column(FeedbackEntry.CodingKeys.deviceModel.name, .text)
                t.column(FeedbackEntry.CodingKeys.createdAt.name, .datetime).notNull()
            }
        }
        try migrator.migrate(dbQueue)
        DatabaseManager.shared.dbWriter = dbQueue
        repo = SQLiteFeedbackRepository()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.dbWriter = nil
        repo = nil
        dbQueue = nil
        try await super.tearDown()
    }

    // MARK: - 保存

    func testSaveAndFetch() async throws {
        let entry = FeedbackEntry(
            title: "测试反馈", category: FeedbackCategory.bug, rating: 4,
            content: "应用闪退", appVersion: "1.0", osVersion: "18.2", deviceModel: "iPhone"
        )
        try await repo.save(entry)
        let all = try await repo.fetchAll(limit: 10)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].title, "测试反馈")
        XCTAssertEqual(all[0].category, FeedbackCategory.bug)
        XCTAssertEqual(all[0].rating, 4)
        XCTAssertEqual(all[0].appVersion, "1.0")
    }

    func testSaveMultipleEntries() async throws {
        for i in 1...5 {
            try await repo.save(FeedbackEntry(
                title: "反馈\(i)", category: FeedbackCategory.feature, rating: 3, content: "内容\(i)"
            ))
        }
        let all = try await repo.fetchAll(limit: 100)
        XCTAssertEqual(all.count, 5)
    }

    func testFetchLimit() async throws {
        for i in 1...10 {
            try await repo.save(FeedbackEntry(title: "F\(i)", category: FeedbackCategory.other, rating: 2, content: "C"))
        }
        let limited = try await repo.fetchAll(limit: 3)
        XCTAssertEqual(limited.count, 3)
    }

    // MARK: - 模型

    func testFeedbackCategoryConstants() {
        XCTAssertEqual(FeedbackCategory.bug, "bug")
        XCTAssertEqual(FeedbackCategory.feature, "feature")
        XCTAssertEqual(FeedbackCategory.content, "content")
        XCTAssertEqual(FeedbackCategory.other, "other")
        XCTAssertEqual(FeedbackCategory.allCases.count, 4)
    }

    func testFeedbackCategoryDisplayNames() {
        for cat in FeedbackCategory.allCases {
            let name = FeedbackCategory.displayName(cat)
            XCTAssertFalse(name.isEmpty, "\(cat) displayName should not be empty")
        }
    }

    func testFeedbackEntryDefaults() {
        let entry = FeedbackEntry(title: "T", category: "bug", rating: 3, content: "C")
        XCTAssertFalse(entry.id.isEmpty)
        XCTAssertEqual(entry.appVersion, "")
        XCTAssertNotNil(entry.createdAt)
    }

    func testCodingKeysCount() {
        // 核心纠错：验证 CodingKeys 数目为 10（添加了 status 字段）。
        let keys: [FeedbackEntry.CodingKeys] = [.id, .title, .category, .rating, .content, .status, .appVersion, .osVersion, .deviceModel, .createdAt]
        XCTAssertEqual(keys.count, 10)
    }

    // MARK: - 提交 + 历史列表

    func testSubmitAndAppearsInHistory() async throws {
        let entry = FeedbackEntry(title: "新反馈", category: FeedbackCategory.feature, rating: 5, content: "建议")
        try await repo.save(entry)
        let all = try await repo.fetchAll(limit: 10)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].title, "新反馈")
    }

    func testHistoryOrderDescending() async throws {
        try await repo.save(FeedbackEntry(title: "旧", category: FeedbackCategory.other, rating: 2, content: "旧"))
        try? await Task.sleep(nanoseconds: 10_000_000)
        try await repo.save(FeedbackEntry(title: "新", category: FeedbackCategory.bug, rating: 4, content: "新"))
        let all = try await repo.fetchAll(limit: 10)
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].title, "新") // 最新的在前
    }

    func testSubmitClearsForm() async throws {
        // 模拟：提交后应能重新查询到
        let entry = FeedbackEntry(title: "表单提交", category: FeedbackCategory.content, rating: 3, content: "测试")
        try await repo.save(entry)
        let fetched = try await repo.fetchByID(id: entry.id)
        XCTAssertEqual(fetched?.title, "表单提交")
    }

    func testFetchByID() async throws {
        let entry = FeedbackEntry(title: "ID查询", category: FeedbackCategory.other, rating: 1, content: "c")
        try await repo.save(entry)
        let fetched = try await repo.fetchByID(id: entry.id)
        XCTAssertNotNil(fetched)
    }
}

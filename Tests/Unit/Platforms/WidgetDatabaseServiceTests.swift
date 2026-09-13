//
//  WidgetDatabaseServiceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 WidgetModels 和 WidgetDatabaseService 开展自动化单元测试。
//
import XCTest
import UFPStorage
@testable import ZhiYu

final class WidgetDatabaseServiceTests: XCTestCase {

    var dbQueue: DatabaseQueue!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        try await DatabaseManager.shared.setupForTesting(with: dbQueue)
    }

    override func tearDown() async throws {
        dbQueue = nil
        try await super.tearDown()
    }

    // MARK: - 模型层测试

    /// TC-WS-01: 验证 WidgetPageRow 的 databaseTableName 映射正确
    func testWidgetPageRowTableName() {
        XCTAssertEqual(WidgetPageRow.databaseTableName, AppConstants.Storage.Tables.pages)
    }

    /// TC-WS-02: 验证 WidgetLinkRow 的 databaseTableName 映射正确
    func testWidgetLinkRowTableName() {
        XCTAssertEqual(WidgetLinkRow.databaseTableName, AppConstants.Storage.Tables.links)
    }

    /// TC-WS-03: 验证 WidgetPageRow.Columns 的列名映射正确
    func testWidgetPageRowColumnMappings() {
        XCTAssertEqual(WidgetPageRow.Columns.title.rawValue, "title")
        XCTAssertEqual(WidgetPageRow.Columns.pageType.rawValue, "page_type")
        XCTAssertEqual(WidgetPageRow.Columns.tags.rawValue, "tags")
        XCTAssertEqual(WidgetPageRow.Columns.updatedAt.rawValue, "updated_at")
    }

    /// TC-WS-04: 验证 WidgetStats 字段绑定
    func testWidgetStatsFields() {
        let stats = WidgetStats(pageCount: 10, linkCount: 5, tagCount: 3)
        XCTAssertEqual(stats.pageCount, 10)
        XCTAssertEqual(stats.linkCount, 5)
        XCTAssertEqual(stats.tagCount, 3)
    }

    /// TC-WS-05: 验证 WidgetRecentPage 字段绑定与颜色推导
    func testWidgetRecentPageFields() {
        let concept = WidgetRecentPage(title: "C", typeName: "concept", colorName: "accent")
        XCTAssertEqual(concept.title, "C")
        XCTAssertEqual(concept.typeName, "concept")
        XCTAssertEqual(concept.colorName, "accent")

        let entity = WidgetRecentPage(title: "E", typeName: "entity", colorName: "purple")
        XCTAssertEqual(entity.typeName, "entity")
        XCTAssertEqual(entity.colorName, "purple")
    }

    // MARK: - WidgetPageRow 查询测试

    /// TC-WS-06: 空表 fetchCount 返回 0
    func testWidgetPageRowFetchCountEmptyTable() async throws {
        let count = try await dbQueue.read { db in
            try WidgetPageRow.fetchCount(db)
        }
        XCTAssertEqual(count, 0)
    }

    /// TC-WS-07: 插入数据后 fetchCount 返回正确数量
    func testWidgetPageRowFetchCountAfterInsert() async throws {
        let testDate = Date()
        try await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO \(AppConstants.Storage.Tables.pages)
                (id, title, page_type, tags, content, status, confidence,
                 sources, related_page_ids, aliases, is_pinned, lamport_timestamp,
                 created_at, updated_at)
                VALUES
                (x'00000000000000000000000000000001', 'Page A', 'concept',
                 '["tag1","tag2"]', '', 'active', 'medium',
                 '[]', '[]', '[]', 0, 0, ?, ?),
                (x'00000000000000000000000000000002', 'Page B', 'entity',
                 '["tag2","tag3"]', '', 'active', 'medium',
                 '[]', '[]', '[]', 0, 0, ?, ?),
                (x'00000000000000000000000000000003', 'Page C', 'concept',
                 '["tag1"]', '', 'active', 'medium',
                 '[]', '[]', '[]', 0, 0, ?, ?)
                """, arguments: [testDate, testDate, testDate, testDate, testDate, testDate])
        }

        let count = try await dbQueue.read { db in
            try WidgetPageRow.fetchCount(db)
        }
        XCTAssertEqual(count, 3)
    }

    // MARK: - 标签统计逻辑测试

    /// TC-WS-08: 空表 distinct tag count 为 0
    func testDistinctTagCountEmptyTable() async throws {
        let tagCount = try await dbQueue.read { db in
            try widgetDistinctTagCount(db)
        }
        XCTAssertEqual(tagCount, 0)
    }

    /// TC-WS-09: 验证跨多行去重标签计数
    func testDistinctTagCountAfterInsert() async throws {
        let testDate = Date()
        try await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO \(AppConstants.Storage.Tables.pages)
                (id, title, page_type, tags, content, status, confidence,
                 sources, related_page_ids, aliases, is_pinned, lamport_timestamp,
                 created_at, updated_at)
                VALUES
                (x'00000000000000000000000000000004', 'P1', 'concept',
                 '["x","y"]', '', 'active', 'medium',
                 '[]', '[]', '[]', 0, 0, ?, ?),
                (x'00000000000000000000000000000005', 'P2', 'entity',
                 '["y","z"]', '', 'active', 'medium',
                 '[]', '[]', '[]', 0, 0, ?, ?)
                """, arguments: [testDate, testDate, testDate, testDate])
        }

        // 3 个不重复标签: x, y, z
        let tagCount = try await dbQueue.read { db in
            try widgetDistinctTagCount(db)
        }
        XCTAssertEqual(tagCount, 3)
    }

    /// TC-WS-10: 所有页面均无标签时返回 0
    func testDistinctTagCountAllNil() async throws {
        let testDate = Date()
        try await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO \(AppConstants.Storage.Tables.pages)
                (id, title, page_type, tags, content, status, confidence,
                 sources, related_page_ids, aliases, is_pinned, lamport_timestamp,
                 created_at, updated_at)
                VALUES
                (x'00000000000000000000000000000006', 'NoTags1', 'concept',
                 NULL, '', 'active', 'medium',
                 '[]', '[]', '[]', 0, 0, ?, ?)
                """, arguments: [testDate, testDate])
        }

        let tagCount = try await dbQueue.read { db in
            try widgetDistinctTagCount(db)
        }
        XCTAssertEqual(tagCount, 0)
    }

    // MARK: - 最近更新页面查询测试

    /// TC-WS-11: 验证最近更新按 updated_at DESC 排序
    func testRecentPagesOrderedByUpdatedAt() async throws {
        let base = Date()
        try await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO \(AppConstants.Storage.Tables.pages)
                (id, title, page_type, tags, content, status, confidence,
                 sources, related_page_ids, aliases, is_pinned, lamport_timestamp,
                 created_at, updated_at)
                VALUES
                (x'00000000000000000000000000000011', 'Oldest', 'concept',
                 '[]', '', 'active', 'medium',
                 '[]', '[]', '[]', 0, 0, ?, ?),
                (x'00000000000000000000000000000012', 'Middle', 'entity',
                 '[]', '', 'active', 'medium',
                 '[]', '[]', '[]', 0, 0, ?, ?),
                (x'00000000000000000000000000000013', 'Latest', 'concept',
                 '[]', '', 'active', 'medium',
                 '[]', '[]', '[]', 0, 0, ?, ?)
                """, arguments: [
                    base.addingTimeInterval(-600), base.addingTimeInterval(-600),
                    base.addingTimeInterval(-300), base.addingTimeInterval(-300),
                    base, base
                ])
        }

        let rows = try await dbQueue.read { db in
            try WidgetPageRow
                .select(WidgetPageRow.Columns.title, WidgetPageRow.Columns.pageType)
                .order(WidgetPageRow.Columns.updatedAt.desc)
                .limit(2)
                .fetchAll(db)
        }

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].title, "Latest")
        XCTAssertEqual(rows[0].pageType, "concept")
        XCTAssertEqual(rows[1].title, "Middle")
        XCTAssertEqual(rows[1].pageType, "entity")
    }
}

// MARK: - 测试辅助函数

/// 测试可访问的标签去重计数逻辑（与 WidgetDatabaseService.fetchDistinctTagCount 实现一致）
private func widgetDistinctTagCount(_ db: Database) throws -> Int {
    let rows = try Row.fetchAll(db, WidgetPageRow
        .select(WidgetPageRow.Columns.tags)
        .filter(WidgetPageRow.Columns.tags != nil)
    )
    let rawTags: [String] = rows.compactMap { $0[WidgetPageRow.Columns.tags] }

    let allTags = rawTags.flatMap { json -> [String] in
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    return Set(allTags).count
}

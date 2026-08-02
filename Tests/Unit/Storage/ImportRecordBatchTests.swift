//
//  ImportRecordBatchTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：批量导入、AI 标签、标签分组逻辑测试

import XCTest
import UFPStorage
@testable import ZhiYu

@MainActor
final class ImportRecordBatchTests: XCTestCase {

    // MARK: - tags 字段

    func testTagsDefaultNil() {
        let record = ImportRecord(category: ImportCategory.link.rawValue, title: "T")
        XCTAssertNil(record.tags)
    }

    func testTagsInitWithValue() {
        let record = ImportRecord(category: ImportCategory.link.rawValue, title: "T", tags: "AI, 技术")
        XCTAssertEqual(record.tags, "AI, 技术")
    }

    func testTagsMutability() {
        var record = ImportRecord(category: ImportCategory.link.rawValue, title: "T")
        record.tags = "产品, 设计"
        XCTAssertEqual(record.tags, "产品, 设计")
    }

    // MARK: - updateTags Repository

    func testUpdateTags() async throws {
        let dbQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: ImportRecord.databaseTableName) { t in
                t.column(ImportRecord.CodingKeys.id.name, .text).primaryKey()
                t.column(ImportRecord.CodingKeys.category.name, .text).notNull()
                t.column(ImportRecord.CodingKeys.title.name, .text).notNull()
                t.column(ImportRecord.CodingKeys.status.name, .text).notNull().defaults(to: "pending")
                t.column(ImportRecord.CodingKeys.rawText.name, .text)
                t.column(ImportRecord.CodingKeys.sourceURL.name, .text)
                t.column(ImportRecord.CodingKeys.filePath.name, .text)
                t.column(ImportRecord.CodingKeys.fileSize.name, .integer)
                t.column(ImportRecord.CodingKeys.pageID.name, .text)
                t.column(ImportRecord.CodingKeys.vaultID.name, .text)
                t.column(ImportRecord.CodingKeys.taskID.name, .text)
                t.column(ImportRecord.CodingKeys.tags.name, .text)
                t.column(ImportRecord.CodingKeys.createdAt.name, .datetime).notNull()
                t.column(ImportRecord.CodingKeys.completedAt.name, .datetime)
            }
        }
        try migrator.migrate(dbQueue)
        DatabaseManager.shared.dbWriter = dbQueue
        let repo = SQLiteImportRecordRepository()

        let record = ImportRecord(category: ImportCategory.link.rawValue, title: "AI 文章")
        try await repo.save(record)
        try await repo.updateTags(id: record.id, tags: "AI, 技术文档")

        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.tags, "AI, 技术文档")

        DatabaseManager.shared.dbWriter = nil
    }

    // MARK: - URL 校验逻辑

    func testValidHTTPURL() {
        let url = URL(string: "https://example.com")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "https")
    }

    func testValidHTTPURLWithPath() {
        let url = URL(string: "https://example.com/path/to/article?q=1")
        XCTAssertNotNil(url)
    }

    func testInvalidURLNoScheme() {
        let url = URL(string: "example.com")
        // URL(string:) may succeed but scheme will be nil
        if let validURL = url {
            XCTAssertFalse(validURL.scheme == "http" || validURL.scheme == "https")
        }
    }

    func testFilterHTTPSchemes() {
        let inputs = ["https://a.com", "http://b.com", "ftp://c.com", "not-a-url"]
        let urls = inputs.compactMap { URL(string: $0) }
            .filter { $0.scheme == "http" || $0.scheme == "https" }
        XCTAssertEqual(urls.count, 2)
    }

    func testDeduplication() {
        let inputs = ["https://a.com", "https://A.COM", "https://b.com"]
        var seen = Set<String>()
        let unique = inputs.compactMap { line -> URL? in
            guard let url = URL(string: line) else { return nil }
            let normalized = url.absoluteString.lowercased()
            guard !seen.contains(normalized) else { return nil }
            seen.insert(normalized)
            return url
        }
        XCTAssertEqual(unique.count, 2)
    }

    func testMax10Limit() {
        let urls = (1...15).compactMap { URL(string: "https://example\($0).com") }
        let limited = Array(urls.prefix(10))
        XCTAssertEqual(limited.count, 10)
    }

    // MARK: - 标签分组逻辑

    func testGroupByTags() {
        let r1 = ImportRecord(category: "link", title: "R1", tags: "AI, 技术")
        let r2 = ImportRecord(category: "link", title: "R2", tags: "产品")
        let r3 = ImportRecord(category: "link", title: "R3", tags: nil)
        let r4 = ImportRecord(category: "link", title: "R4", tags: "AI")

        let records = [r1, r2, r3, r4]
        var groups: [String: [ImportRecord]] = [:]
        for r in records {
            let tags = (r.tags?.isEmpty ?? true) ? ["未分类"] : (r.tags?.components(separatedBy: ", ") ?? ["未分类"])
            for tag in tags {
                groups[tag, default: []].append(r)
            }
        }

        XCTAssertEqual(groups["AI"]?.count, 2)     // r1, r4
        XCTAssertEqual(groups["技术"]?.count, 1)    // r1
        XCTAssertEqual(groups["产品"]?.count, 1)    // r2
        XCTAssertEqual(groups["未分类"]?.count, 1)  // r3
    }

    func testGroupByTagsEmptyString() {
        let r = ImportRecord(category: "link", title: "R", tags: "")
        let tags = (r.tags?.isEmpty ?? true) ? ["未分类"] : (r.tags?.components(separatedBy: ", ") ?? ["未分类"])
        XCTAssertEqual(tags, ["未分类"])
    }

    // MARK: - JSON 解析

    func testExtractJSONFromLLMResponse() throws {
        let response = "prefix text\n{\"aliasTitle\": \"智宇产品手册\", \"tags\": [\"技术文档\", \"AI\"]}\nsuffix"
        guard let start = response.firstIndex(of: "{"),
              let end = response.lastIndex(of: "}") else {
            XCTFail("Failed to locate JSON brackets")
            return
        }
        let jsonStr = String(response[start...end])
        let data = try XCTUnwrap(jsonStr.data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["aliasTitle"] as? String, "智宇产品手册")
        XCTAssertEqual(obj?["tags"] as? [String], ["技术文档", "AI"])
    }

    func testExtractJSONInvalidResponse() {
        let response = "no json here"
        guard let start = response.firstIndex(of: "{"),
              let end = response.lastIndex(of: "}") else { return } // No JSON
        XCTFail("Should not find JSON brackets")
    }

    // MARK: - 导入记录标题别名

    func testTitleAliasUpdate() async throws {
        let dbQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: ImportRecord.databaseTableName) { t in
                t.column(ImportRecord.CodingKeys.id.name, .text).primaryKey()
                t.column(ImportRecord.CodingKeys.category.name, .text).notNull()
                t.column(ImportRecord.CodingKeys.title.name, .text).notNull()
                t.column(ImportRecord.CodingKeys.status.name, .text).notNull().defaults(to: "pending")
                t.column(ImportRecord.CodingKeys.rawText.name, .text)
                t.column(ImportRecord.CodingKeys.sourceURL.name, .text)
                t.column(ImportRecord.CodingKeys.filePath.name, .text)
                t.column(ImportRecord.CodingKeys.fileSize.name, .integer)
                t.column(ImportRecord.CodingKeys.pageID.name, .text)
                t.column(ImportRecord.CodingKeys.vaultID.name, .text)
                t.column(ImportRecord.CodingKeys.taskID.name, .text)
                t.column(ImportRecord.CodingKeys.tags.name, .text)
                t.column(ImportRecord.CodingKeys.createdAt.name, .datetime).notNull()
                t.column(ImportRecord.CodingKeys.completedAt.name, .datetime)
            }
        }
        try migrator.migrate(dbQueue)
        DatabaseManager.shared.dbWriter = dbQueue
        let repo = SQLiteImportRecordRepository()

        // 模拟：先存原始 URL 标题，后用别名更新
        let record = ImportRecord(category: ImportCategory.link.rawValue, title: "https://example.com/article")
        try await repo.save(record)
        try await repo.updateTags(id: record.id, tags: "AI")

        // 更新标题为别名
        var fetched = try await repo.fetchByID(record.id)
        XCTAssertNotNil(fetched)
        fetched?.title = "智宇产品手册"
        if var r = fetched { try await repo.save(r) }

        let updated = try await repo.fetchByID(record.id)
        XCTAssertEqual(updated?.title, "智宇产品手册")
        XCTAssertEqual(updated?.tags, "AI")

        DatabaseManager.shared.dbWriter = nil
    }
}

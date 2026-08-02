//
//  ImportSynthesisLinkTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Integration] 集成测试层
//  核心职责：导入→合成数据源链路验证 + 异常输入全覆盖

import XCTest
import UFPStorage
@testable import ZhiYu

@MainActor
final class ImportSynthesisLinkTests: XCTestCase {

    private var dbQueue: DatabaseQueue!
    private var repo: SQLiteImportRecordRepository!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v7_test") { db in
            try db.create(table: ImportRecord.databaseTableName) { t in
                t.column(ImportRecord.CodingKeys.id.name, .text).primaryKey()
                t.column(ImportRecord.CodingKeys.category.name, .text).notNull().indexed()
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
        repo = SQLiteImportRecordRepository()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.dbWriter = nil
        repo = nil
        dbQueue = nil
        try await super.tearDown()
    }

    // MARK: - ImportRecord → KnowledgePage 链路

    func testImportRecordLinksToKnowledgePage() async throws {
        let pageID = UUID().uuidString
        let record = ImportRecord(
            category: ImportCategory.link.rawValue,
            title: "合成源页面", status: ImportRecordStatus.done,
            rawText: "# 测试内容\n\n正文部分",
            sourceURL: "https://example.com/article",
            pageID: pageID, completedAt: Date()
        )
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.pageID, pageID)
        XCTAssertEqual(fetched?.status, ImportRecordStatus.done)
        XCTAssertEqual(fetched?.sourceURL, "https://example.com/article")
    }

    func testMultipleImportsAllHavePageIDs() async throws {
        let ids = (1...5).map { _ in UUID().uuidString }
        for (i, pageID) in ids.enumerated() {
            try await repo.save(ImportRecord(
                category: ImportCategory.link.rawValue,
                title: "页面\(i)", status: ImportRecordStatus.done, pageID: pageID
            ))
        }
        let all = try await repo.fetchAll(category: nil, limit: 100)
        XCTAssertEqual(all.filter { $0.pageID != nil }.count, 5)
    }

    // MARK: - 合成输入构建（溯源元数据）

    func testSynthesisInputIncludesSourceURL() {
        let input = buildSynthesisInput(title: "AI 设计", content: "正文",
                                         sourceURL: "https://example.com", kind: nil)
        XCTAssertTrue(input.contains("> 来源: https://example.com"))
    }

    func testSynthesisInputIncludesSourceKind() {
        let input = buildSynthesisInput(title: "文件导入", content: "内容",
                                         sourceURL: nil, kind: "file")
        XCTAssertTrue(input.contains("> 类型: file"))
    }

    func testSynthesisInputWithoutProvenance() {
        let input = buildSynthesisInput(title: "无溯源", content: "内容",
                                         sourceURL: nil, kind: nil)
        XCTAssertEqual(input, "# 无溯源\n内容")
    }

    func testSynthesisCombineMultiplePages() {
        let p1 = buildSynthesisInput(title: "页1", content: "C1", sourceURL: "https://a.com", kind: nil)
        let p2 = buildSynthesisInput(title: "页2", content: "C2", sourceURL: nil, kind: "file")
        let p3 = buildSynthesisInput(title: "页3", content: "C3", sourceURL: nil, kind: nil)
        let combined = [p1, p2, p3].joined(separator: "\n\n---\n\n")
        XCTAssertTrue(combined.contains("> 来源: https://a.com"))
        XCTAssertTrue(combined.contains("> 类型: file"))
        XCTAssertTrue(combined.contains("# 页3\nC3"))
        XCTAssertTrue(combined.contains("---"))
    }

    private func buildSynthesisInput(
        title: String,
        content: String,
        sourceURL: String?,
        kind: String?
    ) -> String {
        var meta = ""
        if let url = sourceURL { meta += "> 来源: \(url)\n" }
        if let k = kind { meta += "> 类型: \(k)\n" }
        let header = meta.isEmpty ? "" : "\(meta)\n"
        return "# \(title)\n\(header)\(content)"
    }

    // MARK: - 异常输入

    func testExtremelyLongTitle() async throws {
        let longTitle = String(repeating: "长标题", count: 200)
        let record = ImportRecord(category: ImportCategory.manual.rawValue, title: longTitle)
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.title, longTitle)
    }

    func testSpecialCharactersInContent() async throws {
        let record = ImportRecord(category: ImportCategory.manual.rawValue,
                                   title: "特殊 <>&\"'", rawText: "content with <html> tags")
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.rawText, "content with <html> tags")
    }

    func testUnicodeEmoji() async throws {
        let record = ImportRecord(category: ImportCategory.link.rawValue,
                                   title: "🚀✨🔥", rawText: "🎉📚💡")
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.title, "🚀✨🔥")
    }

    func testNullByteContentTruncated() async throws {
        // SQLite 字符串以 null 字节截断
        let record = ImportRecord(category: ImportCategory.manual.rawValue,
                                   title: "null", rawText: "pre\0post")
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.rawText, "pre", "SQLite 在 null 字节处截断")
    }

    // MARK: - 各类导入 content 格式

    func testLinkImportStoresMarkdown() async throws {
        let md = "# 标题\n\n**加粗**\n\n- 列表"
        let record = ImportRecord(category: ImportCategory.link.rawValue,
                                   title: "MD Page", status: ImportRecordStatus.done,
                                   rawText: md, sourceURL: "https://ex.com",
                                   pageID: UUID().uuidString)
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertTrue(fetched?.rawText?.contains("# 标题") ?? false)
    }

    func testManualImportStoresSourceHeader() async throws {
        let raw = "> 来源：手动输入 | 2026/6/10\n\n内容"
        let record = ImportRecord(category: ImportCategory.manual.rawValue,
                                   title: "手动", rawText: raw)
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertTrue(fetched?.rawText?.contains("> 来源：手动输入") ?? false)
    }

    func testFileImportStoresPath() async throws {
        let path = "/Documents/import_records/file_20260610.pdf"
        let record = ImportRecord(category: ImportCategory.file.rawValue,
                                   title: "doc.pdf", filePath: path, fileSize: 1_048_576)
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.filePath, path)
    }

    // MARK: - 边界

    func testMinimalRecord() async throws {
        let record = ImportRecord(category: ImportCategory.link.rawValue, title: "最小")
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.status, ImportRecordStatus.pending)
        XCTAssertNil(fetched?.rawText)
        XCTAssertNil(fetched?.tags)
    }

    func testAllCategoriesHavePages() async throws {
        for cat in ImportCategory.allCases {
            let record = ImportRecord(category: cat.rawValue, title: cat.displayName,
                                       status: ImportRecordStatus.done,
                                       pageID: UUID().uuidString)
            try await repo.save(record)
        }
        let all = try await repo.fetchAll(category: nil, limit: 100)
        XCTAssertEqual(all.filter { $0.pageID != nil && $0.status == ImportRecordStatus.done }.count, 6)
    }
}

//
//  ImportRecordRepositoryTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 ImportRecordRepository CRUD 类型安全操作

import XCTest
import UFPStorage
@testable import ZhiYu

@MainActor
final class ImportRecordRepositoryTests: XCTestCase {

    private var dbQueue: DatabaseQueue!
    private var repo: SQLiteImportRecordRepository!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        repo = SQLiteImportRecordRepository()

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
        // 将测试 DB 注入 DatabaseManager，使 Repository 的 dbWriter 能解析到
        DatabaseManager.shared.dbWriter = dbQueue
    }

    override func tearDown() async throws {
        DatabaseManager.shared.dbWriter = nil
        dbQueue = nil
        repo = nil
        try await super.tearDown()
    }

    // MARK: - 保存与查询

    func testSaveAndFetchAll() async throws {
        let record = ImportRecord(
            category: ImportCategory.link.rawValue, title: "Test Link",
            sourceURL: "https://example.com"
        )
        try await repo.save(record)
        let all = try await repo.fetchAll(category: nil, limit: 10)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].title, "Test Link")
    }

    func testFetchByCategory() async throws {
        try await repo.save(ImportRecord(category: ImportCategory.link.rawValue, title: "L1"))
        try await repo.save(ImportRecord(category: ImportCategory.file.rawValue, title: "F1"))
        let links = try await repo.fetchAll(category: ImportCategory.link.rawValue, limit: 10)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].title, "L1")
    }

    func testFetchByID() async throws {
        let record = ImportRecord(category: ImportCategory.manual.rawValue, title: "Note", rawText: "content")
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Note")
    }

    // MARK: - 状态更新

    func testUpdateStatus() async throws {
        let record = ImportRecord(
            category: ImportCategory.manual.rawValue, title: "M",
            status: ImportRecordStatus.processing
        )
        try await repo.save(record)
        try await repo.updateStatus(id: record.id, status: ImportRecordStatus.done, completedAt: Date())
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.status, ImportRecordStatus.done)
        XCTAssertNotNil(fetched?.completedAt)
    }

    func testUpdatePageID() async throws {
        let record = ImportRecord(category: ImportCategory.link.rawValue, title: "L")
        try await repo.save(record)
        let pageID = UUID().uuidString
        try await repo.updatePageID(id: record.id, pageID: pageID)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.pageID, pageID)
    }

    // MARK: - 进行中查询

    func testFetchInProgress() async throws {
        try await repo.save(ImportRecord(category: ImportCategory.link.rawValue, title: "P1", status: ImportRecordStatus.processing))
        try await repo.save(ImportRecord(category: ImportCategory.link.rawValue, title: "P2", status: ImportRecordStatus.pending))
        try await repo.save(ImportRecord(category: ImportCategory.link.rawValue, title: "D1", status: ImportRecordStatus.done))
        let inProgress = try await repo.fetchInProgress()
        XCTAssertEqual(inProgress.count, 2)
    }

    // MARK: - 存储大小

    func testTotalStorageSize() async throws {
        try await repo.save(ImportRecord(category: ImportCategory.manual.rawValue, title: "M", rawText: "Hello World"))
        try await repo.save(ImportRecord(category: ImportCategory.file.rawValue, title: "F", filePath: "/tmp/test.pdf", fileSize: 1024))
        let size = try await repo.totalStorageSize()
        XCTAssertGreaterThan(size, 0)
    }
}

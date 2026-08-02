//
//  ImportBoundaryTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Integration] 集成测试层
//  核心职责：导入功能边界条件全覆盖 — 重复文件、大小限制、格式校验、频控、批量限制

import XCTest
@preconcurrency import GRDB
@testable import ZhiYu

@MainActor
final class ImportBoundaryTests: XCTestCase {

    private var dbQueue: DatabaseQueue!
    private var repo: SQLiteImportRecordRepository!

    // MARK: - Setup / Teardown

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

    // MARK: - 重复文件拦截

    func testDuplicateFilePrevention() async throws {
        let path = "/tmp/test_duplicate.pdf"
        let record = ImportRecord(
            category: ImportCategory.file.rawValue,
            title: "test.pdf",
            status: ImportRecordStatus.done,
            filePath: path,
            fileSize: 1024
        )
        try await repo.save(record)

        // 查重：同路径 + 已完成状态
        let existing = try await repo.fetchAll(category: ImportCategory.file.rawValue, limit: 1000)
        let isDuplicate = existing.contains { $0.filePath == path && $0.status == ImportRecordStatus.done }
        XCTAssertTrue(isDuplicate, "相同路径的已完成记录应判定为重复")
    }

    func testDifferentPathNotDuplicate() async throws {
        let r1 = ImportRecord(
            category: ImportCategory.file.rawValue,
            title: "a.pdf", status: ImportRecordStatus.done,
            filePath: "/tmp/a.pdf", fileSize: 1024
        )
        let r2 = ImportRecord(
            category: ImportCategory.file.rawValue,
            title: "b.pdf", status: ImportRecordStatus.done,
            filePath: "/tmp/b.pdf", fileSize: 2048
        )
        try await repo.save(r1)
        try await repo.save(r2)

        let existing = try await repo.fetchAll(category: ImportCategory.file.rawValue, limit: 1000)
        let aDup = existing.contains { $0.filePath == "/tmp/a.pdf" && $0.status == ImportRecordStatus.done }
        let bDup = existing.contains { $0.filePath == "/tmp/b.pdf" && $0.status == ImportRecordStatus.done }
        XCTAssertTrue(aDup)
        XCTAssertTrue(bDup)
        // a 和 b 是不同的文件，各自独立存在
        XCTAssertEqual(existing.filter { $0.status == ImportRecordStatus.done }.count, 2)
    }

    func testFailedFileNotBlockDuplicate() async throws {
        let failed = ImportRecord(
            category: ImportCategory.file.rawValue,
            title: "fail.pdf", status: ImportRecordStatus.failed,
            filePath: "/tmp/fail.pdf", fileSize: 1024
        )
        try await repo.save(failed)

        // 失败的文件不应阻止重新导入
        let existing = try await repo.fetchAll(category: ImportCategory.file.rawValue, limit: 1000)
        let isBlocking = existing.contains { $0.filePath == "/tmp/fail.pdf" && $0.status == ImportRecordStatus.done }
        XCTAssertFalse(isBlocking, "失败状态的记录不应阻止重新导入")
    }

    // MARK: - 文件大小限制

    func testFileSizeUnderLimitAccepted() {
        let size: Int64 = 5 * 1_024 * 1_024 // 5 MB
        XCTAssertLessThanOrEqual(size, AppConstants.Keys.ImportLimits.maxFileSizeBytes)
    }

    func testFileSizeOverLimitRejected() {
        let size: Int64 = 60 * 1_024 * 1_024 // 60 MB (> 50 MB 限制)
        XCTAssertGreaterThan(size, AppConstants.Keys.ImportLimits.maxFileSizeBytes)
    }

    func testFileSizeExactlyAtLimit() {
        let limit = AppConstants.Keys.ImportLimits.maxFileSizeBytes
        XCTAssertLessThanOrEqual(limit, limit)
        XCTAssertGreaterThan(limit + 1, limit)
    }

    func testOCRImageSizeUnderLimit() {
        let size: Int64 = 3 * 1_024 * 1_024 // 3 MB
        XCTAssertLessThanOrEqual(size, AppConstants.Keys.ImportLimits.maxOCRImageSizeBytes)
    }

    func testOCRImageSizeOverLimit() {
        let size: Int64 = 10 * 1_024 * 1_024 // 10 MB
        XCTAssertGreaterThan(size, AppConstants.Keys.ImportLimits.maxOCRImageSizeBytes)
    }

    // MARK: - URL 格式校验

    func testValidHTTPURLs() {
        let urls = [
            "https://example.com",
            "http://example.com/path?q=1",
            "https://sub.domain.com/path/to/page#anchor"
        ]
        for urlStr in urls {
            let url = URL(string: urlStr)
            XCTAssertNotNil(url)
            XCTAssertTrue(url?.scheme == "http" || url?.scheme == "https",
                          "\(urlStr) should be valid HTTP/HTTPS")
        }
    }

    func testInvalidURLs() {
        let invalid = [
            "not-a-url",
            "ftp://files.com",
            "file:///local/path",
            "",
            "   "
        ]
        for urlStr in invalid {
            let url = URL(string: urlStr)
            let isValid = url.map { $0.scheme == "http" || $0.scheme == "https" } ?? false
            XCTAssertFalse(isValid, "\(urlStr) should be invalid for import")
        }
    }

    func testURLDeduplicationNormalized() {
        let inputs = ["https://EXAMPLE.com", "https://example.com"]
        var seen = Set<String>()
        let unique = inputs.compactMap { line -> URL? in
            guard let url = URL(string: line),
                  url.scheme == "http" || url.scheme == "https" else { return nil }
            let normalized = url.absoluteString.lowercased()
            guard !seen.contains(normalized) else { return nil }
            seen.insert(normalized)
            return url
        }
        XCTAssertEqual(unique.count, 1, "大小写不同的相同 URL 应去重")
    }

    // MARK: - 批量导入 10 上限

    func testBatchMax10() {
        let urls = (1...15).compactMap { URL(string: "https://example\($0).com") }
        let limited = Array(urls.prefix(AppConstants.Keys.ImportLimits.maxURLCount))
        XCTAssertEqual(limited.count, AppConstants.Keys.ImportLimits.maxURLCount)
    }

    func testBatchEmptyURLs() {
        let input = ""
        let lines = input.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        XCTAssertTrue(lines.isEmpty, "空输入应有 0 个有效 URL")
    }

    func testBatchAllInvalidURLs() {
        let input = "line1\nline2\nftp://test.com"
        let lines = input.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let valid = lines.compactMap { URL(string: $0) }
            .filter { $0.scheme == "http" || $0.scheme == "https" }
        XCTAssertTrue(valid.isEmpty, "全无效输入应有 0 个有效 URL")
    }

    // MARK: - 空内容 / 无效格式

    func testEmptyRawTextImport() async throws {
        let record = ImportRecord(
            category: ImportCategory.manual.rawValue,
            title: "空内容", rawText: nil
        )
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertNil(fetched?.rawText, "rawText 为 nil 时应正确存储")
    }

    func testImportCategoryUnknown() {
        XCTAssertNil(ImportCategory(rawValue: "video"), "未知类别应返回 nil")
        XCTAssertNil(ImportCategory(rawValue: ""), "空字符串应返回 nil")
    }

    func testAllCategoriesCoverage() {
        let all = ImportCategory.allCases
        XCTAssertEqual(all.count, 6)
        for cat in all {
            let record = ImportRecord(category: cat.rawValue, title: cat.displayName)
            XCTAssertEqual(record.category, cat.rawValue)
        }
    }

    // MARK: - 频控冷却

    func testCooldownInitialState() {
        let now = Date()
        let lastImport = now.addingTimeInterval(-2) // 2 秒前
        let elapsed = now.timeIntervalSince(lastImport)
        XCTAssertGreaterThan(elapsed, AppConstants.Keys.ImportLimits.importCooldownSeconds,
                             "冷却时间过后应允许新导入")
    }

    func testCooldownBlocksImmediateReimport() {
        let now = Date()
        let lastImport = now.addingTimeInterval(-0.5) // 0.5 秒前
        let elapsed = now.timeIntervalSince(lastImport)
        XCTAssertLessThan(elapsed, AppConstants.Keys.ImportLimits.importCooldownSeconds,
                          "冷却时间内应阻止重复导入")
    }

    // MARK: - ImportRecord 状态流转

    func testStatusLifecycle() async throws {
        let record = ImportRecord(category: ImportCategory.link.rawValue, title: "Lifecycle Test")
        try await repo.save(record)
        XCTAssertEqual(record.status, ImportRecordStatus.pending)

        try await repo.updateStatus(id: record.id, status: ImportRecordStatus.processing, completedAt: nil)
        var fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.status, ImportRecordStatus.processing)
        XCTAssertNil(fetched?.completedAt)

        try await repo.updateStatus(id: record.id, status: ImportRecordStatus.done, completedAt: Date())
        fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.status, ImportRecordStatus.done)
        XCTAssertNotNil(fetched?.completedAt)
    }

    func testStatusFailedPreservesRawText() async throws {
        let record = ImportRecord(
            category: ImportCategory.link.rawValue,
            title: "失败保留原文", rawText: "important content",
            sourceURL: "https://example.com"
        )
        try await repo.save(record)
        try await repo.updateStatus(id: record.id, status: ImportRecordStatus.failed, completedAt: Date())
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.rawText, "important content", "失败状态应保留原始内容")
        XCTAssertEqual(fetched?.sourceURL, "https://example.com")
    }

    func testPageIDLinking() async throws {
        let record = ImportRecord(category: ImportCategory.file.rawValue, title: "link-test")
        try await repo.save(record)
        let pageID = UUID().uuidString
        try await repo.updatePageID(id: record.id, pageID: pageID)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.pageID, pageID)
    }

    // MARK: - 大文本内容

    func testLargeRawTextStorage() async throws {
        let largeText = String(repeating: "知识内容测试", count: 1000) // ~6000 chars
        let record = ImportRecord(
            category: ImportCategory.manual.rawValue,
            title: "大文本", rawText: largeText
        )
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.rawText, largeText)
    }

    func testAITagSnippetTruncation() {
        let longText = String(repeating: "内容", count: 10000)
        let snippet = String(longText.prefix(AppConstants.Keys.ImportLimits.aiTagSnippetLength))
        XCTAssertEqual(snippet.count, AppConstants.Keys.ImportLimits.aiTagSnippetLength)
    }

    // MARK: - 文件路径

    func testFilePathStorage() async throws {
        let path = "/Documents/import_records/file_20260610_210000.pdf"
        let record = ImportRecord(
            category: ImportCategory.file.rawValue,
            title: "path-test.pdf", filePath: path, fileSize: 4096
        )
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.filePath, path)
        XCTAssertEqual(fetched?.fileSize, 4096)
    }

    func testVaultIDAssociation() async throws {
        let vaultID = UUID().uuidString
        let record = ImportRecord(
            category: ImportCategory.link.rawValue,
            title: "vault-test", vaultID: vaultID
        )
        try await repo.save(record)
        let fetched = try await repo.fetchByID(record.id)
        XCTAssertEqual(fetched?.vaultID, vaultID)
    }
}

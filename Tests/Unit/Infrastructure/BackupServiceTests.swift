//
//  BackupServiceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 BackupService 开展备份创建、恢复、删除与脏标记的自动化单元测试验证。
//
import XCTest
import SwiftUI
import UFPStorage
@preconcurrency @testable import ZhiYu
@testable import UFPCore

// MARK: - BackupService Tests
@MainActor
final class BackupServiceTests: XCTestCase {

    var backupService: BackupService!
    var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        // 每个测试使用独立临时目录以实现物理隔离
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 注入临时目录
        backupService = BackupService(baseDirectory: tempDir)
    }

    override func tearDown() async throws {
        // 清理临时目录
        try? FileManager.default.removeItem(at: tempDir)
        backupService = nil
        try await super.tearDown()
    }

    func testCreateBackupGeneratesEntry() {
        let pages = [
            KnowledgePage(title: "Page A", pageType: .entity, content: "Content A"),
            KnowledgePage(title: "Page B", pageType: .concept, content: "Content B")
        ]

        backupService.createBackup(pages: pages)

        XCTAssertFalse(backupService.backupEntries.isEmpty, "Backup should create at least one entry")
        let latestEntry = backupService.backupEntries.first
        XCTAssertNotNil(latestEntry?.id)
        XCTAssertEqual(latestEntry?.pageCount, 2)
    }

    func testBackupEntryContainsCorrectMetadata() {
        let pages = [KnowledgePage(title: "Test", pageType: .source, content: "x")]
        backupService.createBackup(pages: pages)

        let entry = backupService.backupEntries.first
        XCTAssertNotNil(entry?.timestamp)
        XCTAssertEqual(entry?.pageCount, 1)
        XCTAssertGreaterThan(entry?.totalWords ?? 0, 0)
    }

    func testRestoreBackupReturnsCorrectPages() {
        let original = [
            KnowledgePage(title: "Restored Page", pageType: .entity, content: "Restored content"),
            KnowledgePage(title: "Page 2", pageType: .concept, content: "More content here with enough chars")
        ]
        backupService.createBackup(pages: original)

        let entries = backupService.backupEntries
        guard let latestEntry = entries.first else {
            XCTFail("No backup entry found"); return
        }

        let restored = backupService.restoreBackup(latestEntry)
        XCTAssertNotNil(restored, "Restore should return pages array")
        XCTAssertEqual(restored?.count, 2, "Should restore all pages")
        XCTAssertTrue(restored?.contains { $0.title == "Restored Page" } ?? false)
    }

    func testDeleteBackupRemovesEntry() {
        let pages = [KnowledgePage(title: "To Delete", pageType: .raw, content: "content")]
        backupService.createBackup(pages: pages)

        let countBefore = backupService.backupEntries.count
        guard let entryToDelete = backupService.backupEntries.first else {
            XCTFail("No entry to delete"); return
        }

        backupService.deleteBackup(entryToDelete)
        XCTAssertEqual(backupService.backupEntries.count, countBefore - 1)
    }

    func testMarkDirtyAndClean() {
        backupService.markDirty()
        XCTAssertTrue(backupService.hasUnsavedChanges)

        backupService.markClean()
        XCTAssertFalse(backupService.hasUnsavedChanges)
    }

    func testMultipleBackupsCreateMultipleEntries() {
        for i in 0..<3 {
            let pages = [KnowledgePage(title: "Page \(i)", pageType: .entity, content: "Content \(i)")]
            backupService.createBackup(pages: pages)
            backupService.lastBackupDate = nil
        }
        XCTAssertEqual(backupService.backupEntries.count, 3)
    }
}

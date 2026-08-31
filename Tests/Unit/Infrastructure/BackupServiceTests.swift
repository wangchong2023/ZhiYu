//
//  BackupServiceTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 BackupService 的备份创建/恢复/删除、节流、自动清理与崩溃恢复逻辑。
//

import XCTest
@testable import ZhiYu

@MainActor
final class BackupServiceSupplementTests: XCTestCase {

    private var tempDir: URL!
    private var service: BackupService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("BackupTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = BackupService(baseDirectory: tempDir)
    }

    override func tearDown() {
        service = nil
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - 辅助方法

    private func makePage(title: String = "Test Page", content: String = "Hello World") -> KnowledgePage {
        KnowledgePage(title: title, content: content)
    }

    // MARK: - 初始化

    func testInit_createsBackupDirectory() {
        let backupDir = service.backupDirectory
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupDir.path))
    }

    func testInit_emptyDirectory_backupEntriesIsEmpty() {
        XCTAssertTrue(service.backupEntries.isEmpty)
    }

    func testInit_loadsExistingIndex() {
        let pages = [makePage(title: "Page1"), makePage(title: "Page2")]
        service.createBackup(pages: pages)

        let newService = BackupService(baseDirectory: tempDir)
        XCTAssertEqual(newService.backupEntries.count, 1)
    }

    // MARK: - createBackup

    func testCreateBackup_createsEntryAndFile() {
        let pages = [makePage(title: "Test")]
        service.createBackup(pages: pages)

        XCTAssertEqual(service.backupEntries.count, 1)
        XCTAssertEqual(service.backupEntries[0].pageCount, 1)

        let fileURL = service.backupDirectory.appendingPathComponent(service.backupEntries[0].fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testCreateBackup_recordsTotalWords() {
        let pages = [makePage(content: "one two three four five")]
        service.createBackup(pages: pages)
        XCTAssertEqual(service.backupEntries[0].totalWords, 5)
    }

    func testCreateBackup_updatesLastBackupDate() {
        XCTAssertNil(service.lastBackupDate)
        service.createBackup(pages: [makePage()])
        XCTAssertNotNil(service.lastBackupDate)
    }

    func testCreateBackup_autoBackupDisabled_skipsBackup() {
        service.isAutoBackupEnabled = false
        service.createBackup(pages: [makePage()])
        XCTAssertTrue(service.backupEntries.isEmpty)
    }

    func testCreateBackup_throttleWithin300s_skipsBackup() {
        service.createBackup(pages: [makePage()])
        XCTAssertEqual(service.backupEntries.count, 1)

        service.createBackup(pages: [makePage()])
        XCTAssertEqual(service.backupEntries.count, 1)
    }

    func testCreateBackup_multiplePages_correctCount() {
        let pages = [makePage(title: "A"), makePage(title: "B"), makePage(title: "C")]
        service.createBackup(pages: pages)
        XCTAssertEqual(service.backupEntries[0].pageCount, 3)
    }

    func testCreateBackup_emptyPages_stillCreatesBackup() {
        service.createBackup(pages: [])
        XCTAssertEqual(service.backupEntries.count, 1)
        XCTAssertEqual(service.backupEntries[0].pageCount, 0)
    }

    // MARK: - restoreBackup

    func testRestoreBackup_returnsOriginalPages() throws {
        let pages = [makePage(title: "Original")]
        service.createBackup(pages: pages)

        let entry = service.backupEntries[0]
        let restored = service.restoreBackup(entry)

        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.count, 1)
        XCTAssertEqual(restored?[0].title, "Original")
    }

    func testRestoreBackup_nonExistentFile_returnsNil() {
        let fakeEntry = BackupService.BackupEntry(
            id: UUID(), timestamp: Date(), pageCount: 0, totalWords: 0,
            fileName: "nonexistent_backup.json"
        )
        let result = service.restoreBackup(fakeEntry)
        XCTAssertNil(result)
    }

    func testRestoreBackup_preservesContent() throws {
        let pages = [makePage(title: "Test", content: "Special content 123")]
        service.createBackup(pages: pages)

        let restored = service.restoreBackup(service.backupEntries[0])
        XCTAssertEqual(restored?[0].content, "Special content 123")
    }

    // MARK: - deleteBackup

    func testDeleteBackup_removesEntryAndFile() {
        service.createBackup(pages: [makePage()])
        XCTAssertEqual(service.backupEntries.count, 1)

        let entry = service.backupEntries[0]
        let fileURL = service.backupDirectory.appendingPathComponent(entry.fileName)

        service.deleteBackup(entry)
        XCTAssertEqual(service.backupEntries.count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testDeleteBackup_multipleEntries_removesOnlyTarget() {
        // 创建第一个备份
        service.createBackup(pages: [makePage(title: "A")])

        // 绕过节流创建第二个备份
        service.lastBackupDate = Date().addingTimeInterval(-400)
        service.createBackup(pages: [makePage(title: "B")])

        XCTAssertEqual(service.backupEntries.count, 2)

        service.deleteBackup(service.backupEntries[0])
        XCTAssertEqual(service.backupEntries.count, 1)
    }

    // MARK: - markDirty / markClean / hasUnsavedChanges

    func testMarkDirty_setsHasUnsavedChanges() {
        XCTAssertFalse(service.hasUnsavedChanges)
        service.markDirty()
        XCTAssertTrue(service.hasUnsavedChanges)
    }

    func testMarkClean_clearsHasUnsavedChanges() {
        service.markDirty()
        XCTAssertTrue(service.hasUnsavedChanges)
        service.markClean()
        XCTAssertFalse(service.hasUnsavedChanges)
    }

    func testMarkClean_whenNotDirty_noError() {
        XCTAssertFalse(service.hasUnsavedChanges)
        service.markClean()
        XCTAssertFalse(service.hasUnsavedChanges)
    }

    // MARK: - 崩溃恢复

    func testInit_withDirtyFlag_removesFlagOnRecovery() {
        service.markDirty()
        XCTAssertTrue(service.hasUnsavedChanges)

        let newService = BackupService(baseDirectory: tempDir)
        XCTAssertFalse(newService.hasUnsavedChanges)
    }

    func testInit_withoutDirtyFlag_noCrashRecovery() {
        let newService = BackupService(baseDirectory: tempDir)
        XCTAssertFalse(newService.hasUnsavedChanges)
    }

    // MARK: - 自动清理 (maxBackups = 20)

    func testCleanOldBackups_keepsOnly20Entries() {
        // 创建 22 个备份，每个间隔超过 300s 以避开节流
        for i in 0..<22 {
            service.lastBackupDate = Date().addingTimeInterval(-Double(300 + i * 10))
            service.createBackup(pages: [makePage(title: "Backup_\(i)")])
        }

        XCTAssertLessThanOrEqual(service.backupEntries.count, 20)
    }

    // MARK: - scanBackupDirectory (index 文件缺失时)

    func testScanBackupDirectory_recoversFromBackupFiles() {
        // 创建备份
        service.createBackup(pages: [makePage(title: "Scanned")])

        // 删除 index 文件，强制走 scanBackupDirectory 路径
        let indexURL = service.backupDirectory.appendingPathComponent("backup_index.json")
        try? FileManager.default.removeItem(at: indexURL)

        // 重新初始化，应通过扫描目录恢复
        let newService = BackupService(baseDirectory: tempDir)
        XCTAssertEqual(newService.backupEntries.count, 1)
        XCTAssertEqual(newService.backupEntries[0].pageCount, 1)
    }

    // MARK: - BackupEntry

    func testBackupEntry_displayName_isNonEmpty() {
        service.createBackup(pages: [makePage()])
        XCTAssertFalse(service.backupEntries[0].displayName.isEmpty)
    }

    func testBackupEntry_fileSize_returnsFormattedString() {
        service.createBackup(pages: [makePage(content: "test content")])
        let size = service.backupEntries[0].fileSize(in: service.backupDirectory)
        XCTAssertFalse(size.isEmpty)
        XCTAssertNotEqual(size, "-")
    }

    func testBackupEntry_fileSize_nonExistentFile_returnsDash() {
        let entry = BackupService.BackupEntry(
            id: UUID(), timestamp: Date(), pageCount: 0, totalWords: 0,
            fileName: "nonexistent.json"
        )
        XCTAssertEqual(entry.fileSize(in: service.backupDirectory), "-")
    }

    // MARK: - defaultBackupDirectory

    func testDefaultBackupDirectory_isUnderDocuments() {
        let dir = BackupService.defaultBackupDirectory()
        XCTAssertTrue(dir.path.contains("Documents"))
        XCTAssertTrue(dir.lastPathComponent == "AppBackups")
    }
}

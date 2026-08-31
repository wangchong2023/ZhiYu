//
//  BackupServiceEdgeCaseTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 BackupService 的节流逻辑、maxBackups 清理、
//           crash recovery dirty flag、restore 往返一致性等边界条件。
//

import XCTest
@testable import ZhiYu

@MainActor
final class BackupServiceEdgeTests: XCTestCase {

    var tempDir: URL!
    var backupService: BackupService!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        backupService = BackupService(baseDirectory: tempDir)
    }

    override func tearDownWithError() throws {
        backupService = nil
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    // MARK: - 辅助方法

    private func makePages(count: Int = 1) -> [KnowledgePage] {
        (0..<count).map { i in
            KnowledgePage(title: "BackupPage\(i)", content: "内容\(i)")
        }
    }

    // MARK: - createBackup 节流

    /// 验证：首次备份不受节流限制。
    func testFirstBackupNotThrottled() async throws {
        let pages = makePages(count: 2)
        backupService.createBackup(pages: pages)

        XCTAssertEqual(backupService.backupEntries.count, 1, "首次备份应成功")
        XCTAssertNotNil(backupService.lastBackupDate)
    }

    /// 验证：禁用自动备份时不创建备份。
    func testAutoBackupDisabledSkipsBackup() {
        backupService.isAutoBackupEnabled = false
        backupService.createBackup(pages: makePages())

        XCTAssertTrue(backupService.backupEntries.isEmpty, "禁用自动备份时不应创建")
    }

    /// 验证：5 分钟内的第二次备份被节流跳过。
    func testBackupThrottledWithinInterval() {
        let pages = makePages()
        backupService.createBackup(pages: pages)
        XCTAssertEqual(backupService.backupEntries.count, 1)

        // 立即再次备份应被节流
        backupService.createBackup(pages: pages)
        XCTAssertEqual(backupService.backupEntries.count, 1, "5 分钟内的第二次备份应被节流")
    }

    // MARK: - maxBackups 清理

    /// 验证：超过 maxBackups(20) 个备份时自动清理最旧的。
    func testCleanOldBackupsRemovesExcess() async throws {
        backupService.isAutoBackupEnabled = true

        // 创建 22 个备份，每次间隔超过节流时间
        for i in 0..<22 {
            // 模拟 lastBackupDate 为过去时间以绕过节流
            backupService.lastBackupDate = Date().addingTimeInterval(-400)
            backupService.createBackup(pages: makePages(count: 1))
        }

        XCTAssertLessThanOrEqual(backupService.backupEntries.count, 20, "备份数量不应超过 maxBackups(20)")
    }

    /// 验证：恰好 20 个备份时不触发清理。
    func testCleanOldBackupsAtExactLimit() async throws {
        for i in 0..<20 {
            backupService.lastBackupDate = Date().addingTimeInterval(-400)
            backupService.createBackup(pages: makePages(count: 1))
        }

        XCTAssertEqual(backupService.backupEntries.count, 20, "恰好 20 个不应被清理")
    }

    // MARK: - restoreBackup 往返一致性

    /// 验证：备份后恢复的数据与原始数据一致。
    func testRestoreBackupPreservesData() async throws {
        let originalPages = makePages(count: 3)
        backupService.lastBackupDate = Date().addingTimeInterval(-400)
        backupService.createBackup(pages: originalPages)

        guard let entry = backupService.backupEntries.first else {
            XCTFail("应有备份记录")
            return
        }

        let restored = backupService.restoreBackup(entry)
        XCTAssertNotNil(restored, "恢复应成功")
        XCTAssertEqual(restored?.count, 3, "恢复的页面数量应一致")
        XCTAssertEqual(restored?.map { $0.title }.sorted(),
                       originalPages.map { $0.title }.sorted(),
                       "恢复的标题应一致")
    }

    /// 验证：恢复不存在的备份文件返回 nil。
    func testRestoreNonExistentBackupReturnsNil() {
        let fakeEntry = BackupService.BackupEntry(
            id: UUID(),
            timestamp: Date(),
            pageCount: 0,
            totalWords: 0,
            fileName: "nonexistent_backup.json"
        )

        let result = backupService.restoreBackup(fakeEntry)
        XCTAssertNil(result, "不存在的备份文件应返回 nil")
    }

    // MARK: - deleteBackup

    /// 验证：deleteBackup 删除备份记录和物理文件。
    func testDeleteBackupRemovesEntryAndFile() async throws {
        backupService.lastBackupDate = Date().addingTimeInterval(-400)
        backupService.createBackup(pages: makePages())

        guard let entry = backupService.backupEntries.first else {
            XCTFail("应有备份记录")
            return
        }

        let fileURL = backupService.backupDirectory.appendingPathComponent(entry.fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "备份文件应存在")

        backupService.deleteBackup(entry)

        XCTAssertFalse(backupService.backupEntries.contains { $0.id == entry.id }, "记录应被删除")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "物理文件应被删除")
    }

    // MARK: - crash recovery dirty flag

    /// 验证：markDirty 创建 dirty flag 文件。
    func testMarkDirtyCreatesFlagFile() {
        backupService.markDirty()
        XCTAssertTrue(backupService.hasUnsavedChanges, "markDirty 后应标记为有未保存更改")
    }

    /// 验证：markClean 删除 dirty flag 文件。
    func testMarkCleanRemovesFlagFile() {
        backupService.markDirty()
        backupService.markClean()
        XCTAssertFalse(backupService.hasUnsavedChanges, "markClean 后应无未保存更改标记")
    }

    /// 验证：初始化时检测到 dirty flag 触发 crash recovery 日志。
    func testCrashRecoveryOnInitWithDirtyFlag() async throws {
        // 先创建 dirty flag
        let dirtyFlag = tempDir.appendingPathComponent(".knowledge-management_dirty")
        try Data().write(to: dirtyFlag)

        // 重新初始化 BackupService 应检测到 dirty flag
        let newService = BackupService(baseDirectory: tempDir)

        // crash recovery 应删除 dirty flag
        XCTAssertFalse(newService.hasUnsavedChanges, "crash recovery 后 dirty flag 应被清除")
    }

    // MARK: - 空页面备份

    /// 验证：空页面列表也能正常备份。
    func testBackupEmptyPagesList() async throws {
        backupService.lastBackupDate = Date().addingTimeInterval(-400)
        backupService.createBackup(pages: [])

        XCTAssertEqual(backupService.backupEntries.count, 1, "空页面列表也应能备份")
        XCTAssertEqual(backupService.backupEntries.first?.pageCount, 0)
    }

    // MARK: - Bug #56: createForcedBackup 绕过 isAutoBackupEnabled 开关

    /// 验证：`isAutoBackupEnabled=false` 时 `createForcedBackup` 仍能创建备份。
    /// 这是"立即创建备份"按钮的核心场景，避免静默失效。
    func testForcedBackupBypassesAutoBackupDisabled() {
        backupService.isAutoBackupEnabled = false
        backupService.createForcedBackup(pages: makePages(count: 2))

        XCTAssertEqual(backupService.backupEntries.count, 1, "强制备份应绕过自动备份开关")
        XCTAssertEqual(backupService.backupEntries.first?.pageCount, 2)
    }

    /// 验证：`createForcedBackup` 不受节流限制。
    func testForcedBackupBypassesThrottle() {
        let pages = makePages(count: 1)
        backupService.createForcedBackup(pages: pages)
        XCTAssertEqual(backupService.backupEntries.count, 1)

        // 立即再次强制备份，不应被节流
        backupService.createForcedBackup(pages: pages)
        XCTAssertEqual(backupService.backupEntries.count, 2, "强制备份不应被节流")
    }

    /// 验证：`createBackup`（自动）在开关关闭时仍静默跳过，与 `createForcedBackup` 行为区分。
    func testAutoBackupStillRespectsToggleWhileForcedBackupDoesNot() {
        backupService.isAutoBackupEnabled = false

        backupService.createBackup(pages: makePages())
        XCTAssertTrue(backupService.backupEntries.isEmpty, "自动备份应受开关控制")

        backupService.createForcedBackup(pages: makePages())
        XCTAssertEqual(backupService.backupEntries.count, 1, "强制备份应绕过开关")
    }

    // MARK: - Bug #57: 恢复前安全备份必须强制执行

    /// 验证：恢复流程中即使 `isAutoBackupEnabled=false`，安全备份仍能创建。
    /// 模拟 BackupView.restoreFromBackup 的安全备份步骤。
    func testRestoreSafetyBackupWorksWhenAutoBackupDisabled() {
        backupService.isAutoBackupEnabled = false

        // 先准备一个可恢复的备份
        backupService.createForcedBackup(pages: makePages(count: 1))
        guard let entry = backupService.backupEntries.first else {
            XCTFail("应有备份记录")
            return
        }

        // 恢复前的安全备份（应使用 createForcedBackup）
        let safetyPages = makePages(count: 5)
        backupService.createForcedBackup(pages: safetyPages)
        XCTAssertEqual(backupService.backupEntries.count, 2, "安全备份应成功创建")

        // 恢复操作本身仍应正常
        let restored = backupService.restoreBackup(entry)
        XCTAssertNotNil(restored, "恢复应成功")
    }
}

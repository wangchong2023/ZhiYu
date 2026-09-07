//
//  BackupServiceForcedBackupTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 存储层测试
//  核心职责：验证 BackupService 强制备份绕过自动备份开关、绕过节流限制以及恢复前安全备份的创建。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class BackupServiceForcedBackupTests: XCTestCase {

    /// 验证 createForcedBackup 在 isAutoBackupEnabled=false 时仍能创建备份
    func testForcedBackup_autoBackupDisabled_stillCreatesBackup() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForcedBackupTest_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let service = BackupService(baseDirectory: tempDir)
        service.isAutoBackupEnabled = false

        service.createForcedBackup(pages: [KnowledgePage(title: "Test")])
        XCTAssertEqual(service.backupEntries.count, 1, "强制备份应绕过自动备份开关")
    }

    /// 验证 createForcedBackup 不受节流限制
    func testForcedBackup_rapidCalls_bypassesThrottle() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForcedThrottle_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let service = BackupService(baseDirectory: tempDir)
        service.createForcedBackup(pages: [KnowledgePage(title: "A")])
        service.createForcedBackup(pages: [KnowledgePage(title: "B")])
        XCTAssertEqual(service.backupEntries.count, 2, "强制备份不应被节流")
    }

    /// 验证恢复前安全备份在自动备份关闭时仍能创建
    func testRestoreBackup_safetyBackupCreated_whenAutoBackupDisabled() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RestoreSafety_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let service = BackupService(baseDirectory: tempDir)
        service.isAutoBackupEnabled = false

        service.createForcedBackup(pages: [KnowledgePage(title: "Original")])
        guard let entry = service.backupEntries.first else {
            XCTFail("应有备份记录")
            return
        }

        service.createForcedBackup(pages: [KnowledgePage(title: "Safety")])
        XCTAssertEqual(service.backupEntries.count, 2, "安全备份应成功创建")

        let restored = service.restoreBackup(entry)
        XCTAssertNotNil(restored, "恢复应成功")
    }
}

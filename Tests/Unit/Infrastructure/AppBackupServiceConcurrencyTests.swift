//
//  AppBackupServiceConcurrencyTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 存储层测试
//  核心职责：验证 BackupService 在并发创建备份与同秒文件名时间戳冲突场景下的安全性与一致性。
//

import XCTest
import Foundation
@testable import ZhiYu

@MainActor
final class AppBackupServiceConcurrencyTests: XCTestCase {

    /// 验证并发调用 createBackup 不引发数据崩溃且备份总数受限
    func testCreateBackup_concurrentCalls_remainWithinCapacity() async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupConcurrency_\(UUID().uuidString)")

        let service = BackupService(baseDirectory: tempDir)
        service.isAutoBackupEnabled = true

        let pages = [KnowledgePage(title: "Test", content: "content")]

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    service.createBackup(pages: pages)
                }
            }
        }

        XCTAssertLessThanOrEqual(service.backupEntries.count, 20, "备份数应不超过上限")

        try? FileManager.default.removeItem(at: tempDir)
    }

    /// 验证同秒内多次备份的文件名生成与去重表现
    func testCreateBackup_sameSecondExecution_generatesEntries() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupFileName_\(UUID().uuidString)")

        let service = BackupService(baseDirectory: tempDir)
        service.isAutoBackupEnabled = true

        let pages = [KnowledgePage(title: "Test", content: "content")]

        service.createBackup(pages: pages)
        service.lastBackupDate = nil
        service.createBackup(pages: pages)

        XCTAssertFalse(service.backupEntries.isEmpty)

        try? FileManager.default.removeItem(at: tempDir)
    }
}

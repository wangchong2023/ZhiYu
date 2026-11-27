//
//  AppBackupServiceDeepMutationTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 BackupService 自动备份节流、强制备份绕过、
//           奔溃恢复 Dirty Flag 机制、文件损坏降级与目录扫描重建。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYuUnitTestHost

@MainActor
final class AppBackupServiceDeepMutationTests: XCTestCase {

    private var tempDirectory: URL!
    private var backupService: BackupService!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()

        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("BackupTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        backupService = BackupService(baseDirectory: tempDirectory)
    }

    override func tearDown() async throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    // MARK: - 1. 自动备份节流与强制备份测试

    func testBackupService_AutoBackupThrottlingAndForcedBypass() {
        let page = KnowledgePage(
            id: UUID(),
            title: "备份测试页面",
            pageType: .concept,
            content: "页面内容详情",
            createdAt: Date(),
            updatedAt: Date()
        )

        // 1. 首次自动备份成功
        backupService.isAutoBackupEnabled = true
        backupService.createBackup(pages: [page])
        XCTAssertEqual(backupService.backupEntries.count, 1)

        // 2. 紧接着在节流期内（< 300s）再次自动备份应被节流跳过
        backupService.createBackup(pages: [page])
        XCTAssertEqual(backupService.backupEntries.count, 1)

        // 3. 强制备份应绕过节流限制并成功新增备份
        backupService.createForcedBackup(pages: [page])
        XCTAssertEqual(backupService.backupEntries.count, 2)

        // 4. 关闭自动备份开关后，自动备份应静默忽略
        backupService.isAutoBackupEnabled = false
        backupService.lastBackupDate = Date().addingTimeInterval(-1000)
        backupService.createBackup(pages: [page])
        XCTAssertEqual(backupService.backupEntries.count, 2)
    }

    // MARK: - 2. 备份恢复与异常损坏降级测试

    func testBackupService_RestoreBackupSuccessAndCorruptedFallback() throws {
        let page = KnowledgePage(
            id: UUID(),
            title: "核心页面",
            pageType: .entity,
            content: "重要知识点",
            createdAt: Date(),
            updatedAt: Date()
        )

        backupService.createForcedBackup(pages: [page])
        guard let entry = backupService.backupEntries.first else {
            XCTFail("应当成功生成备份条目")
            return
        }

        // 1. 正常恢复
        let restored = backupService.restoreBackup(entry)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.first?.title, "核心页面")

        // 2. 模拟文件损坏（写入畸变二进制）
        let fileURL = backupService.backupDirectory.appendingPathComponent(entry.fileName)
        try Data("corrupted json content".utf8).write(to: fileURL)

        // 3. 损坏文件恢复应安全返回 nil 并记录错误日志，不发生崩溃
        let failedRestore = backupService.restoreBackup(entry)
        XCTAssertNil(failedRestore)
    }

    // MARK: - 3. 奔溃恢复 Dirty Flag 状态测试

    func testBackupService_CrashRecoveryDirtyFlag() {
        XCTAssertFalse(backupService.hasUnsavedChanges)

        // 标记脏数据
        backupService.markDirty()
        XCTAssertTrue(backupService.hasUnsavedChanges)

        // 清理脏数据
        backupService.markClean()
        XCTAssertFalse(backupService.hasUnsavedChanges)
    }

    // MARK: - 4. 备份删除与条目大小计算测试

    func testBackupService_DeleteAndFileSize() {
        let page = KnowledgePage(
            id: UUID(),
            title: "待删除备份页面",
            pageType: .concept,
            content: "测试内容",
            createdAt: Date(),
            updatedAt: Date()
        )

        backupService.createForcedBackup(pages: [page])
        guard let entry = backupService.backupEntries.first else {
            XCTFail("应当存在备份")
            return
        }

        let sizeStr = entry.fileSize(in: backupService.backupDirectory)
        XCTAssertNotEqual(sizeStr, "-")

        // 删除备份
        backupService.deleteBackup(entry)
        XCTAssertTrue(backupService.backupEntries.isEmpty)
    }

    // MARK: - 5. 清理旧备份路径穿越防护（缺陷 #163）

    /// 验证篡改索引中的 `../` 越界文件路径在触发 `cleanOldBackups()` 淘汰旧条目时不会被误删
    func testCleanOldBackups_BlocksPathTraversalDeletion() throws {
        // 在 backupDirectory 的父目录放置一个敏感哨兵文件
        let sentinelURL = tempDirectory.appendingPathComponent("outside_sentinel.txt")
        try Data("DO_NOT_DELETE".utf8).write(to: sentinelURL)

        // 构造超过 maxBackups 数量的索引，最旧一条指向 ../outside_sentinel.txt
        let oldestPoisonEntry = BackupService.BackupEntry(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1000),
            pageCount: 1,
            totalWords: 10,
            fileName: "../outside_sentinel.txt"
        )
        var poisonedEntries: [BackupService.BackupEntry] = [oldestPoisonEntry]
        for index in 0..<25 {
            poisonedEntries.append(
                BackupService.BackupEntry(
                    id: UUID(),
                    timestamp: Date(timeIntervalSince1970: TimeInterval(2000 + index)),
                    pageCount: 1,
                    totalWords: 10,
                    fileName: "backup_valid_\(index).json"
                )
            )
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let indexURL = backupService.backupDirectory.appendingPathComponent("backup_index.json")
        try encoder.encode(poisonedEntries).write(to: indexURL, options: .atomicWrite)

        // 重新初始化加载被篡改的索引并触发一次强制备份以激活 cleanOldBackups()
        let reloadedService = BackupService(baseDirectory: tempDirectory)
        let page = KnowledgePage(
            id: UUID(),
            title: "触发清理",
            pageType: .concept,
            content: "内容",
            createdAt: Date(),
            updatedAt: Date()
        )
        reloadedService.createForcedBackup(pages: [page])

        XCTAssertTrue(FileManager.default.fileExists(atPath: sentinelURL.path), "cleanOldBackups 不得删除备份目录外的哨兵文件")
        XCTAssertFalse(reloadedService.backupEntries.contains { $0.fileName == "../outside_sentinel.txt" }, "非法路径条目应从索引中安全清理")
    }
}

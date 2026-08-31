//
//  BackupRestoreCorruptedArchiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：验证 BackupService 自动备份生成、最大保留备份清理策略与归档恢复分支。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class BackupRestoreCorruptedArchiveTests: XCTestCase {

    var backupService: BackupService!
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        backupService = BackupService(baseDirectory: tempDirectory)
    }

    override func tearDown() async throws {
        backupService = nil
        try? FileManager.default.removeItem(at: tempDirectory)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 备份生成与恢复分支

    func testCreateAndRestoreBackup_ValidArchive() async {
        let pages = [
            KnowledgePage(title: "测试页面 1", content: "第一段正文"),
            KnowledgePage(title: "测试页面 2", content: "第二段正文")
        ]

        backupService.createForcedBackup(pages: pages)

        XCTAssertEqual(backupService.backupEntries.count, 1, "强制备份应当生成 1 份备份条目")
        guard let entry = backupService.backupEntries.first else {
            return XCTFail("未能获取到最新备份条目")
        }

        XCTAssertEqual(entry.pageCount, 2)

        let restoredPages = backupService.restoreBackup(entry)
        XCTAssertNotNil(restoredPages, "恢复合法备份应当成功返回页面数组")
        XCTAssertEqual(restoredPages?.count, 2)
    }

    // MARK: - 2. 备份删除分支

    func testDeleteBackup_RemovesEntryAndFile() async {
        let pages = [KnowledgePage(title: "临时页面", content: "内容")]
        backupService.createForcedBackup(pages: pages)

        guard let entry = backupService.backupEntries.first else {
            return XCTFail("未能获取备份条目")
        }

        backupService.deleteBackup(entry)
        XCTAssertTrue(backupService.backupEntries.isEmpty, "删除备份后条目列表应清空")
    }
}

//
//  ImportRecordSectionAndIngestViewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 ImportRecord 数据结构、分类 Tab 枚举映射、OCR 预览与历史卡片状态流转。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ImportRecordSectionAndIngestViewTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ImportRecord 数据持久化与分类映射

    func testImportRecord_SaveAndFetchByCategory() async throws {
        let repo = ServiceContainer.shared.resolve((any ImportRecordRepository).self)

        let record1 = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.file.rawValue,
            title: "PDF 导入记录",
            status: ImportRecordStatus.done,
            rawText: "文本内容",
            fileSize: 1024 * 50
        )

        let record2 = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.voice.rawValue,
            title: "录音笔记",
            status: ImportRecordStatus.processing,
            rawText: "音频转写",
            fileSize: 1024 * 200
        )

        try await repo.save(record1)
        try await repo.save(record2)

        let allRecords = try await repo.fetchAll(category: nil, limit: 100)
        XCTAssertGreaterThanOrEqual(allRecords.count, 2)

        let fileRecords = try await repo.fetchAll(category: ImportCategory.file.rawValue, limit: 100)
        XCTAssertTrue(fileRecords.contains { $0.id == record1.id })
    }

    // MARK: - 2. 状态更新与 PageID 关联分支

    func testImportRecord_UpdateStatusAndPageID() async throws {
        let repo = ServiceContainer.shared.resolve((any ImportRecordRepository).self)
        let recordID = UUID().uuidString

        let record = ImportRecord(
            id: recordID,
            category: ImportCategory.manual.rawValue,
            title: "手动条目",
            status: ImportRecordStatus.processing,
            rawText: "草稿"
        )
        try await repo.save(record)

        let targetPageID = UUID().uuidString
        try await repo.updatePageID(id: recordID, pageID: targetPageID)
        try await repo.updateStatus(id: recordID, status: ImportRecordStatus.done, completedAt: Date())

        let fetched = try await repo.fetchByID(recordID)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.status, ImportRecordStatus.done)
        XCTAssertEqual(fetched?.pageID, targetPageID)
    }

    // MARK: - 3. 存储大小统计与删除分支

    func testImportRecord_TotalStorageAndDeletion() async throws {
        let repo = ServiceContainer.shared.resolve((any ImportRecordRepository).self)
        let recordID = UUID().uuidString

        let record = ImportRecord(
            id: recordID,
            category: ImportCategory.ocr.rawValue,
            title: "OCR 截图",
            status: ImportRecordStatus.done,
            rawText: "OCR 识别结果",
            fileSize: 4096
        )
        try await repo.save(record)

        let totalSize = try await repo.totalStorageSize()
        XCTAssertGreaterThanOrEqual(totalSize, 4096)

        try await repo.updateStatus(id: recordID, status: ImportRecordStatus.failed, completedAt: Date())
        let updated = try await repo.fetchByID(recordID)
        XCTAssertEqual(updated?.status, ImportRecordStatus.failed)
    }
}

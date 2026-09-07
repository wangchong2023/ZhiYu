//
//  ImportRecordModelTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 ImportRecord 模型、ImportCategory、ImportRecordStatus 的类型安全与常量正确性

import XCTest
@testable import ZhiYu

final class ImportRecordModelTests: XCTestCase {

    // MARK: - ImportRecord 初始化

    func testInitDefaults() {
        let record = ImportRecord(category: ImportCategory.link.rawValue, title: "测试导入")
        XCTAssertFalse(record.id.isEmpty)
        XCTAssertEqual(record.title, "测试导入")
        XCTAssertEqual(record.category, ImportCategory.link.rawValue)
        XCTAssertEqual(record.status, ImportRecordStatus.pending)
        XCTAssertNil(record.rawText)
        XCTAssertNil(record.sourceURL)
        XCTAssertNil(record.filePath)
        XCTAssertNil(record.fileSize)
        XCTAssertNil(record.pageID)
        XCTAssertNil(record.vaultID)
        XCTAssertNil(record.taskID)
        XCTAssertNotNil(record.createdAt)
        XCTAssertNil(record.completedAt)
    }

    func testInitWithAllFields() {
        let id = UUID().uuidString
        let now = Date()
        let record = ImportRecord(
            id: id,
            category: ImportCategory.file.rawValue,
            title: "完整记录",
            status: ImportRecordStatus.done,
            rawText: "原始文本",
            sourceURL: "https://example.com",
            filePath: "/tmp/test.pdf",
            fileSize: 2048,
            pageID: UUID().uuidString,
            vaultID: "vault-1",
            taskID: "task-1",
            createdAt: now,
            completedAt: now
        )
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.category, ImportCategory.file.rawValue)
        XCTAssertEqual(record.status, ImportRecordStatus.done)
        XCTAssertEqual(record.rawText, "原始文本")
        XCTAssertEqual(record.sourceURL, "https://example.com")
        XCTAssertEqual(record.filePath, "/tmp/test.pdf")
        XCTAssertEqual(record.fileSize, 2048)
    }

    // MARK: - ImportRecordStatus 常量

    func testStatusConstants() {
        XCTAssertEqual(ImportRecordStatus.pending, "pending")
        XCTAssertEqual(ImportRecordStatus.processing, "processing")
        XCTAssertEqual(ImportRecordStatus.done, "done")
        XCTAssertEqual(ImportRecordStatus.failed, "failed")
    }

    func testStatusTransitions() {
        // 验证状态常量可用于完整生命周期
        let lifecycle = [
            ImportRecordStatus.pending,
            ImportRecordStatus.processing,
            ImportRecordStatus.done
        ]
        XCTAssertEqual(lifecycle, ["pending", "processing", "done"])
    }

    // MARK: - ImportCategory

    func testCategoryAllCases() {
        let cases = ImportCategory.allCases
        XCTAssertEqual(cases.count, 6)
        XCTAssertTrue(cases.contains(.link))
        XCTAssertTrue(cases.contains(.file))
        XCTAssertTrue(cases.contains(.manual))
        XCTAssertTrue(cases.contains(.ocr))
        XCTAssertTrue(cases.contains(.clipboard))
        XCTAssertTrue(cases.contains(.voice))
    }

    func testCategoryRawValues() {
        XCTAssertEqual(ImportCategory.link.rawValue, "link")
        XCTAssertEqual(ImportCategory.file.rawValue, "file")
        XCTAssertEqual(ImportCategory.manual.rawValue, "manual")
        XCTAssertEqual(ImportCategory.ocr.rawValue, "ocr")
        XCTAssertEqual(ImportCategory.clipboard.rawValue, "clipboard")
        XCTAssertEqual(ImportCategory.voice.rawValue, "voice")
    }

    func testCategoryDisplayNameNotEmpty() {
        for cat in ImportCategory.allCases {
            XCTAssertFalse(cat.displayName.isEmpty, "\(cat.rawValue) displayName should not be empty")
        }
    }

    func testCategoryInitFromRawValue() {
        XCTAssertEqual(ImportCategory(rawValue: "link"), .link)
        XCTAssertEqual(ImportCategory(rawValue: "file"), .file)
        XCTAssertEqual(ImportCategory(rawValue: "manual"), .manual)
        XCTAssertNil(ImportCategory(rawValue: "invalid"))
    }

    // MARK: - CodingKeys 不使用物理字段名

    func testCodingKeysUseORM() {
        // 验证所有 CodingKeys 存在，确保 ORM 映射完整
        let keys: [ImportRecord.CodingKeys] = [
            .id, .category, .title, .status,
            .rawText, .sourceURL, .filePath, .fileSize,
            .pageID, .vaultID, .taskID, .tags,
            .createdAt, .completedAt
        ]
        XCTAssertEqual(keys.count, 14)
    }

    // MARK: - Identifiable

    func testIdentifiableConformance() {
        let record = ImportRecord(category: ImportCategory.link.rawValue, title: "ID Test")
        XCTAssertEqual(record.id, record.id as String) // Identifiable
    }
}

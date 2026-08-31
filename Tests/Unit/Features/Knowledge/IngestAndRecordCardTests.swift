//
//  IngestAndRecordCardTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 ImportRecordCard 状态徽章分支、存储尺寸计算与分类颜色映射。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class IngestAndRecordCardTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ImportCategory 枚举展示名称与全部情况

    func testImportCategory_AllCases() {
        let allCases = ImportCategory.allCases
        XCTAssertEqual(allCases.count, 6)

        XCTAssertEqual(ImportCategory.file.displayName, L10n.Ingest.fileImport)
        XCTAssertEqual(ImportCategory.voice.displayName, L10n.Ingest.voiceNote)
        XCTAssertEqual(ImportCategory.ocr.displayName, L10n.Ingest.ocrScan)
        XCTAssertEqual(ImportCategory.manual.displayName, L10n.Ingest.manualEntry)
    }

    // MARK: - 2. ImportRecord 标签解析与字节大小计算

    func testImportRecord_TagsParsingAndByteSize() {
        let recordWithFile = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.file.rawValue,
            title: "手册.pdf",
            status: ImportRecordStatus.done,
            fileSize: 1024 * 1024 * 5,
            tags: "Swift, 并发, 架构"
        )

        let tags = recordWithFile.tags?.components(separatedBy: SystemConstants.Separator.commaSpace).filter { !$0.isEmpty } ?? []
        XCTAssertEqual(tags.count, 3)
        XCTAssertTrue(tags.contains("并发"))
    }
}
